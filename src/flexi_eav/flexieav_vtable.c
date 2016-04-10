//
// Created by slanska on 2016-04-08.
//

#include <string.h>
#include <printf.h>
#include <assert.h>
#include "../../lib/sqlite/sqlite3ext.h"
#include "../../src/misc/json1.h"

SQLITE_EXTENSION_INIT3

/*
 * Internally used structures, subclassed from SQLite structs
 */

struct flexi_prop_col_map
{
    sqlite3_int64 iPropID;
    int iCol;
};

struct flexi_prop_metadata
{
    sqlite3_int64 iPropID;
    sqlite3_int64 iNameID;
    int type;
    unsigned char *regex;
    double maxValue;
    double minValue;
    int maxLength;
    int minOccurences;
    int maxOccurences;
    sqlite3_value *defaultValue;
    int bIndexed;
    int bUnique;
    int bFullTextIndex;
    int xRole;
    unsigned char *zName;
};

struct flexi_vtab
{
    unsigned char base[sizeof(sqlite3_vtab)];
    sqlite3 *db;
    sqlite3_int64 iClassID;

    /*
     * Number of columns, i.e. items in property and column arrays
     */
    int nCols;

    /*
     * Actual length of pProps array (>= nCols)
     */
    int nPropColsAllocated;

    // Sorted array of mapping between property ID and column index
    struct flexi_prop_col_map *pSortedProps;

    // Array of property metadata, by column index
    struct flexi_prop_metadata *pProps;

    unsigned const char *zHash;
    sqlite3_int64 iNameID;
    int bSystemClass;
    int xCtloMask;
};

/*
 *
 */
static void flexi_vtab_prop_free(struct flexi_prop_metadata const *prop)
{
    sqlite3_value_free(prop->defaultValue);
    sqlite3_free(prop->zName);
    sqlite3_free(prop->regex);
}

/*
 * Sorts flexi_vtab->pSortedProps, using bubble sort (should be good enough for this case as we expect only 2-3 dozens of items, at most).
 */
static void flexi_sort_cols_by_prop_id(struct flexi_vtab *vtab)
{
    for (int i = 0; i < vtab->nCols; i++)
    {
        for (int j = 0; j < (vtab->nCols - i - 1); j++)
        {
            if (vtab->pSortedProps[j].iPropID > vtab->pSortedProps[j + 1].iPropID)
            {
                struct flexi_prop_col_map temp = vtab->pSortedProps[j];
                vtab->pSortedProps[j] = vtab->pSortedProps[j + 1];
                vtab->pSortedProps[j + 1] = temp;
            }
        }
    }
}

/*
 * Performs binary search on sorted array of propertyID-column index map
 */
static int flex_get_col_idx_by_prop_id(struct flexi_vtab *vtab, sqlite3_int64 iPropID)
{
    int low = 1;
    int mid;
    int high = vtab->nCols;
    do
    {
        mid = (low + high) / 2;
        if (iPropID < vtab->pSortedProps[mid].iPropID)
            high = mid - 1;
        else
            if (iPropID > vtab->pSortedProps[mid].iPropID)
                low = mid + 1;
    } while (iPropID != vtab->pSortedProps[mid].iPropID && low <= high);
    if (iPropID == vtab->pSortedProps[mid].iPropID)
    {
        return mid;
    }

    return -1;
}

struct flexi_column_data
{
    sqlite3_int64 lPropID;
    sqlite3_int64 lPropIdx;
    int ctlv;
    sqlite3_value *pVal;
};

struct flexi_vtab_cursor
{
    unsigned char base[sizeof(struct sqlite3_vtab_cursor)];
    sqlite3_stmt *pObjectIterator;
    sqlite3_stmt *pPropertyIterator;
    sqlite3_int64 lObjectID;

    /*
     * Number of columns/properties
     */
    int iCol;

    /*
     * Actually fetched number of column values.
     * Reset to 0 on every next object fetch
     */
    int iReadCol;

    /*
     * Array of column data, by their index
     */
    struct flexi_column_data *pCols;


    int bEof;
};

// Utility macros
#define strAppend(SB, S)    jsonAppendRaw(SB, (const char *)S, strlen((const char *)S))
#define strFree(SB)         jsonReset(SB)
#define CHECK(result)       CHECK2(result, FAILURE)
#define CHECK2(result, label)       if (result != SQLITE_OK) goto label;
#define CHECK_CALL(call)       result = (call); \
        if (result != SQLITE_OK) goto CATCH;
#define CHECK_MALLOC(v, s) v = sqlite3_malloc(s); \
        if (v == NULL) { result = SQLITE_NOMEM; goto CATCH;}

static void flexi_vtab_free(struct flexi_vtab *vtab)
{
    if (vtab != NULL)
    {
        if (vtab->pProps != NULL)
        {
            struct flexi_prop_metadata *prop = vtab->pProps;
            for (int idx = 0; idx < vtab->nCols; idx++)
            {
                flexi_vtab_prop_free(prop);
                prop++;
            }
        }

        sqlite3_free(vtab->pSortedProps);
        sqlite3_free(vtab->pProps);
        sqlite3_free((void *) vtab->zHash);
        sqlite3_free(vtab);
    }
}

/*
 * Creates new class
 */
static int flexiEavCreate(
        sqlite3 *db,
        // User data
        void *pAux,
        int argc,

        // argv[0] - module name. Will be 'flexi_eav'
        // argv[1] - database name ("main", "temp" etc.)
        // argv [2] - name of new table (class)
        // argv[3+] - arguments (property specifications/column declarations)
        const char *const *argv,

        // Result of function - table spec
        sqlite3_vtab **ppVTab,
        char **pzErr)
{
    assert(argc >= 4);

    int result = SQLITE_OK;

    // Disposable resources
    sqlite3_stmt *pGetClsPropStmt = NULL;
    sqlite3_stmt *pGetClassStmt = NULL;
    sqlite3_stmt *pExtractProps = NULL;
    sqlite3_stmt *pInsClsStmt = NULL;
    sqlite3_stmt *pInsPropStmt = NULL;
    struct flexi_vtab *vtab = NULL;
    StringBuilder *zCreate = NULL;

    CHECK_MALLOC(vtab, sizeof(struct flexi_vtab));
    memset(vtab, 0, sizeof(*vtab));

    CHECK_MALLOC(zCreate, sizeof(StringBuilder));

    jsonInit(zCreate, NULL);

    strAppend(zCreate, "create table [");
    strAppend(zCreate, argv[2]);
    strAppend(zCreate, "] (");

    // We expect 1st argument passed (at argv[3]) to be valid JSON which describes class
    // (should follow IClassDefinition specification)

    const char *zExtractPropSQL = "select"
            "coalesce(json_extract(value, '$.indexed'), 0) as indexed," // 0
            "coalesce(json_extract(value, '$.unique'), 0) as unique," // 1
            "coalesce(json_extract(value, '$.fastTextSearch'), 0) as fastTextSearch," // 2
            "coalesce(json_extract(value, '$.role'), 0) as role," // 3
            "coalesce(json_extract(value, '$.rules.type'), 0) as type," // 4
            "json_extract(value, '$.rules.regex') as regex," // 5
            "coalesce(json_extract(value, '$.rules.minOccurences'), 0) as minOccurences," // 6
            "coalesce(json_extract(value, '$.rules.maxOccurences'), 1) as maxOccurences," // 7
            "json_extract(value, '$.rules.maxLength') as maxLength," // 8
            "json_extract(value, '$.rules.minValue') as minValue, " // 9
            "json_extract(value, '$.rules.maxValue') as maxValue, " // 10
            "json_extract(value, '$.defaultValue') as defaultValue, " // 11
            "key as prop_name" // 12
            "from json_each(:1, '$.properties')";

    CHECK_CALL(sqlite3_prepare_v2(db, zExtractPropSQL, (int) strlen(zExtractPropSQL), &pExtractProps, NULL));
    CHECK_CALL(sqlite3_bind_text(pExtractProps, 1, argv[2], (int) strlen(argv[2]), NULL));

    int iPropCnt = 0;

    // Initially allocate 10 property slots
    vtab->nPropColsAllocated = 10;
    CHECK_MALLOC(vtab->pProps, vtab->nPropColsAllocated * sizeof(struct flexi_prop_metadata));
    while (1)
    {
        int iStep = sqlite3_step(pExtractProps);
        if (iStep == SQLITE_DONE)
            break;

        if (iStep != SQLITE_ROW)
        {
            result = iStep;
            goto CATCH;
        }

        if (iPropCnt >= vtab->nPropColsAllocated)
        {
            vtab->nPropColsAllocated += 10;
            void *tmpProps;
            int newLen = vtab->nPropColsAllocated * sizeof(struct flexi_prop_metadata);
            CHECK_MALLOC(tmpProps, newLen);
            memcpy(tmpProps, vtab->pProps, iPropCnt * sizeof(struct flexi_prop_metadata));
            vtab->pProps = tmpProps;
        }

        vtab->pProps[iPropCnt].bIndexed = sqlite3_column_int(pExtractProps, 0);
        vtab->pProps[iPropCnt].bUnique = sqlite3_column_int(pExtractProps, 1);
        vtab->pProps[iPropCnt].bFullTextIndex = sqlite3_column_int(pExtractProps, 2);
        vtab->pProps[iPropCnt].xRole = sqlite3_column_int(pExtractProps, 3);
        vtab->pProps[iPropCnt].type = sqlite3_column_int(pExtractProps, 4);
        vtab->pProps[iPropCnt].regex = (unsigned char *) sqlite3_column_text(pExtractProps, 5);
        vtab->pProps[iPropCnt].minOccurences = sqlite3_column_int(pExtractProps, 6);
        vtab->pProps[iPropCnt].maxOccurences = sqlite3_column_int(pExtractProps, 7);
        vtab->pProps[iPropCnt].maxLength = sqlite3_column_int(pExtractProps, 8);
        vtab->pProps[iPropCnt].minValue = sqlite3_column_double(pExtractProps, 9);
        vtab->pProps[iPropCnt].maxValue = sqlite3_column_double(pExtractProps, 10);
        vtab->pProps[iPropCnt].defaultValue = sqlite3_value_dup(sqlite3_column_value(pExtractProps, 11));
        vtab->pProps[iPropCnt].zName = (unsigned char *) sqlite3_column_text(pExtractProps, 12);

        if (iPropCnt != 0)
        {
            strAppend(zCreate, ",");
        }
        strAppend(zCreate, "[");
        strAppend(zCreate, vtab->pProps[iPropCnt].zName);
        strAppend(zCreate, "]");

        iPropCnt++;
    }
    vtab->nCols = iPropCnt;

    strAppend(zCreate, ");");

    // insert into .classes
    const char *zInsClsSQL = "insert or replace into [.names] ([Value]) values (:1);"
            "insert into [.classes] (NameID, ) values ((select NameID from [.names] where [Value] = :1 limit 1),"
            " :2, :3);select last_insert_rowid();";
    CHECK_CALL(sqlite3_prepare_v2(db, zInsClsSQL, (int) strlen(zInsClsSQL), &pInsClsStmt, NULL));
    sqlite3_bind_text(pInsClsStmt, 1, argv[2], (int) strlen(argv[2]), NULL);
    if (sqlite3_step(pInsClsStmt) != SQLITE_ROW)
    {
        result = SQLITE_NOTFOUND;
        goto CATCH;
    }
    vtab->iClassID = sqlite3_column_int64(pInsClsStmt, 0);

    const char *zInsPropSQL = "insert or replace into [.names] ([Value]) values (:1);"
            "insert into [.class_properties] (ClassID, NameID) values (:2, "
            "(select NameID from [.names] where [Value] = :1 limit 1));";
    CHECK_CALL(sqlite3_prepare_v2(db, zInsPropSQL, (int) strlen(zInsPropSQL), &pInsPropStmt, NULL));

    struct flexi_prop_metadata *pProp = vtab->pProps;
    for (int idx = 0; idx < vtab->nCols; idx++, pProp++)
    {
        sqlite3_reset(pInsPropStmt);
        sqlite3_bind_int64(pInsPropStmt, 2, vtab->iClassID);
        sqlite3_step(pInsPropStmt);
    }

    // Fix strange issue with terminating zero
    zCreate->zBuf[zCreate->nUsed] = 0;
    CHECK_CALL(sqlite3_declare_vtab(db, zCreate->zBuf));

    *ppVTab = (void *) vtab;

    // Init table data
    vtab->db = db;
    vtab->nCols = iPropCnt;
    CHECK_MALLOC(vtab->pSortedProps, vtab->nCols * sizeof(struct flexi_prop_col_map));
    //CHECK_MALLOC(vtab->pProps, vtab->nCols * sizeof(struct flexi_prop_metadata));

    memset(vtab->pSortedProps, 0, vtab->nCols * sizeof(struct flexi_prop_col_map));
    // memset(vtab->pProps, 0, vtab->nCols * sizeof(struct flexi_prop_metadata));

    // Init property metadata
    const char *zGetClassSQL = "select "
            "ClassID, " // 0
            "NameID, " // 1
            "SystemClass, " // 2
            "ctloMask, " // 3
            "Hash " // 4
            "from [.classes] "
            "where NameID = (select NameID from [.names] where [Value] = :1) limit 1;";
    CHECK_CALL(sqlite3_prepare_v2(db, zGetClassSQL, (int) strlen(zGetClassSQL), &pGetClassStmt, NULL));
    CHECK_CALL(sqlite3_bind_text(pExtractProps, 1, argv[2], (int) strlen(argv[2]), NULL));
    while (1)
    {
        result = sqlite3_step(pExtractProps);
        if (result == SQLITE_DONE)
            break;

        if (result != SQLITE_ROW)
            goto CATCH;

    }

    CHECK_CALL(sqlite3_bind_text(pGetClassStmt, 1, argv[2], (int) strlen(argv[2]), NULL));
    result = (sqlite3_step(pGetClassStmt));
    if (result == SQLITE_DONE)
        // No class found. Return error
    {
        result = SQLITE_NOTFOUND;
        *pzErr = "Cannot find Flexilite class"; // TODO inject class name
        goto CATCH;
    }

    if (sqlite3_step(pGetClassStmt) != SQLITE_ROW)
        goto CATCH;

    vtab->iClassID = sqlite3_column_int64(pGetClassStmt, 0);
    vtab->iNameID = sqlite3_column_int64(pGetClassStmt, 1);
    vtab->bSystemClass = sqlite3_column_int(pGetClassStmt, 2);
    vtab->xCtloMask = sqlite3_column_int(pGetClassStmt, 3);
    vtab->zHash = sqlite3_column_text(pGetClassStmt, 4);

    const char *zGetClsPropSQL = "select "
            "cp.NameID, " // 0
            "cp.PropertyID, " // 1
            "json_extract(c.Data, printf('$.properties.%d.indexed', cp.PropertyID)) as indexed," // 2
            "json_extract(c.Data, printf('$.properties.%d.unique', cp.PropertyID)) as unique," // 3
            "json_extract(c.Data, printf('$.properties.%d.fastTextSearch', cp.PropertyID)) as fastTextSearch," // 4
            "json_extract(c.Data, printf('$.properties.%d.role', cp.PropertyID)) as role," // 5
            "json_extract(c.Data, printf('$.properties.%d.rules.type', cp.PropertyID)) as type," // 6
            "json_extract(c.Data, printf('$.properties.%d.rules.regex', cp.PropertyID)) as regex," // 7
            "json_extract(c.Data, printf('$.properties.%d.rules.minOccurences', cp.PropertyID)) as minOccurences," // 8
            "json_extract(c.Data, printf('$.properties.%d.rules.maxOccurences', cp.PropertyID)) as maxOccurences," // 9
            "json_extract(c.Data, printf('$.properties.%d.rules.maxLength', cp.PropertyID)) as maxLength," // 10
            "json_extract(c.Data, printf('$.properties.%d.rules.minValue', cp.PropertyID)) as minValue, " // 11
            "json_extract(c.Data, printf('$.properties.%d.rules.maxValue', cp.PropertyID)) as maxValue, " // 12
            "json_extract(c.Data, printf('$.properties.%d.defaultValue', cp.PropertyID)) as defaultValue " // 13
            "from [.class_properties] cp "
            "join [.classes] c on cp.ClassID = c.ClassID"
            "where cp.ClassID = :1 order by PropertyID;";
    CHECK_CALL(sqlite3_prepare_v2(db, zGetClsPropSQL, (int) strlen(zGetClsPropSQL), &pGetClassStmt, NULL));
    sqlite3_bind_int64(pGetClsPropStmt, 1, vtab->iClassID);

    int nPropIdx = 0;
    do
    {
        int stepResult = sqlite3_step(pGetClsPropStmt);
        if (stepResult != SQLITE_ROW)
            break;

        nPropIdx++;
        vtab->pProps[nPropIdx].iNameID = sqlite3_column_int64(pGetClsPropStmt, 0);
        vtab->pProps[nPropIdx].iPropID = sqlite3_column_int64(pGetClsPropStmt, 1);
        vtab->pProps[nPropIdx].bIndexed = sqlite3_column_int(pGetClsPropStmt, 2);
        vtab->pProps[nPropIdx].bUnique = sqlite3_column_int(pGetClsPropStmt, 3);
        vtab->pProps[nPropIdx].bFullTextIndex = sqlite3_column_int(pGetClsPropStmt, 4);
        vtab->pProps[nPropIdx].xRole = sqlite3_column_int(pGetClsPropStmt, 5);
        vtab->pProps[nPropIdx].type = sqlite3_column_int(pGetClsPropStmt, 6);
        vtab->pProps[nPropIdx].regex = (unsigned char *) sqlite3_column_text(pGetClsPropStmt, 7);
        vtab->pProps[nPropIdx].minOccurences = sqlite3_column_int(pGetClsPropStmt, 8);
        vtab->pProps[nPropIdx].maxOccurences = sqlite3_column_int(pGetClsPropStmt, 9);
        vtab->pProps[nPropIdx].maxLength = sqlite3_column_int(pGetClsPropStmt, 10);
        vtab->pProps[nPropIdx].minValue = sqlite3_column_double(pGetClsPropStmt, 11);
        vtab->pProps[nPropIdx].maxValue = sqlite3_column_double(pGetClsPropStmt, 12);
        vtab->pProps[nPropIdx].defaultValue = sqlite3_value_dup(sqlite3_column_value(pGetClsPropStmt, 13));

    } while (1);

    // Check if number of loaded properties matches expected number of columns in the vtable definition
    if (nPropIdx != iPropCnt)
    {
        result = SQLITE_CONSTRAINT_VTAB;
        goto CATCH;
    }

    // Init property-column map (unsorted)


    // Sort prop-col map
    flexi_sort_cols_by_prop_id(vtab);

    goto FINALLY;

    CATCH:
    // Release resources because of errors (catch)
    flexi_vtab_free(vtab);

    FINALLY:
    // Release all temporary resources
    strFree(zCreate);
    sqlite3_finalize(pGetClassStmt);
    sqlite3_finalize(pGetClsPropStmt);
    sqlite3_finalize(pExtractProps);
    sqlite3_finalize(pInsClsStmt);
    sqlite3_finalize(pInsPropStmt);

    return result;
}

/* Connects to flexi_eav virtual table. */
static int flexiEavConnect(
        sqlite3 *db,

        // User data
        void *pAux,
        int argc, const char *const *argv,
        sqlite3_vtab **ppVtab,
        char **pzErr
)
{
    // TODO Temp
    int result = flexiEavCreate(db, pAux, argc, argv, ppVtab, pzErr);
    return result;
}

/*
 *
 */
static int flexiEavDisconnect(sqlite3_vtab *pVTab)
{
    flexi_vtab_free((void *) pVTab);
    return SQLITE_OK;
}

/*
 * Finds best existing index for the given criteria, based on index definition for class' properties
 *   struct sqlite3_index_info {
 *   */
// Inputs
//const int nConstraint;     /* Number of entries in aConstraint */
//const struct sqlite3_index_constraint {
//    int iColumn;              /* Column constrained.  -1 for ROWID */
//    unsigned char op;         /* Constraint operator */
//    unsigned char usable;     /* True if this constraint is usable */
//    int iTermOffset;          /* Used internally - xBestIndex should ignore */
//} *const aConstraint;      /* Table of WHERE clause constraints */
//const int nOrderBy;        /* Number of terms in the ORDER BY clause */
//const struct sqlite3_index_orderby {
//    int iColumn;              /* Column number */
//    unsigned char desc;       /* True for DESC.  False for ASC. */
//} *const aOrderBy;         /* The ORDER BY clause */
//
///* Outputs */
//struct sqlite3_index_constraint_usage {
//    int argvIndex;           /* if >0, constraint is part of argv to xFilter */
//    unsigned char omit;      /* Do not code a test for this constraint */
//} *const aConstraintUsage;
//int idxNum;                /* Number used to identify the index */
//char *idxStr;              /* String, possibly obtained from sqlite3_malloc */
//int needToFreeIdxStr;      /* Free idxStr using sqlite3_free() if true */
//int orderByConsumed;       /* True if output is already ordered */
//double estimatedCost;      /* Estimated cost of using this index */
///* Fields below are only available in SQLite 3.8.2 and later */
//sqlite3_int64 estimatedRows;    /* Estimated number of rows returned */
///* Fields below are only available in SQLite 3.9.0 and later */
//int idxFlags;              /* Mask of SQLITE_INDEX_SCAN_* flags */
///* Fields below are only available in SQLite 3.10.0 and later */
//sqlite3_uint64 colUsed;    /* Input: Mask of columns used by statement */
//};

static int flexiEavBestIndex(
        sqlite3_vtab *tab,
        sqlite3_index_info *pIdxInfo
)
{
#define SQLITE_INDEX_CONSTRAINT_EQ      2
#define SQLITE_INDEX_CONSTRAINT_GT      4
#define SQLITE_INDEX_CONSTRAINT_LE      8
#define SQLITE_INDEX_CONSTRAINT_LT     16
#define SQLITE_INDEX_CONSTRAINT_GE     32
#define SQLITE_INDEX_CONSTRAINT_MATCH  64
#define SQLITE_INDEX_CONSTRAINT_LIKE   65     /* 3.10.0 and later only */
#define SQLITE_INDEX_CONSTRAINT_GLOB   66     /* 3.10.0 and later only */
#define SQLITE_INDEX_CONSTRAINT_REGEXP 67     /* 3.10.0 and later only */
#define SQLITE_INDEX_SCAN_UNIQUE        1     /* Scan visits at most 1 row */

    // Get class info
    // Find property by column index
    // Check if property is indexed or not
    // Check if property is nullable or not

    // For simple ops (==, <= etc.) try to apply index

    // For match, like and glob - try to apply full text index, if applicable

    // For regexp - will do scan

    pIdxInfo->idxNum = 1;
    pIdxInfo->estimatedCost = 40;
    pIdxInfo->idxStr = "1";
    pIdxInfo->aConstraintUsage[0].argvIndex = 1;

    return SQLITE_OK;

}

/*
 * Delete class
 */
static int flexiEavDestroy(sqlite3_vtab *pVTab)
{
    //pVTab->pModule
    // TODO "delete from [.classes] where NameID = "
    return SQLITE_OK;
}

/*
 * Starts SELECT on a Flexilite class
 */
static int flexiEavOpen(sqlite3_vtab *pVTab, sqlite3_vtab_cursor **ppCursor)
{
    // Cursor will have 2 prepared sqlite statements: 1) find object IDs by property values (either with index or not), 2) to iterate through found objects' properties
    struct flexi_vtab_cursor *cur = sqlite3_malloc(sizeof(struct flexi_vtab_cursor));
    if (cur == NULL)
        return SQLITE_NOMEM;

    *ppCursor = (void *) cur;
    memset(cur, 0, sizeof(*cur));

    cur->bEof = 0;
    cur->lObjectID = -1;
    struct flexi_vtab *vtab = (void *) pVTab;
    const char *zObjSql = "select ObjectID, ClassID, ctlo from [.objects]";
    int result = sqlite3_prepare_v2(vtab->db, zObjSql, (int) strlen(zObjSql), &cur->pObjectIterator, NULL);
    if (result == SQLITE_OK)
    {
        const char *zPropSql = "select * from [.ref-values] where ObjectID = $ObjectID";
        result = sqlite3_prepare_v2(vtab->db, zPropSql, (int) strlen(zPropSql), &cur->pPropertyIterator, NULL);
    }

    return result;
}

/*
 * Finishes SELECT
 */
static int flexiEavClose(sqlite3_vtab_cursor *pCursor)
{
    struct flexi_vtab_cursor *cur = (void *) pCursor;
    sqlite3_finalize(cur->pObjectIterator);
    sqlite3_finalize(cur->pPropertyIterator);
    sqlite3_free(pCursor);
    return SQLITE_OK;
}

/*
 * Begins search
 * idxNum will have indexed property ID
 */
static int flexiEavFilter(sqlite3_vtab_cursor *pCursor, int idxNum, const char *idxStr,
                          int argc, sqlite3_value **argv)
{
    if (argc > 0)
    {
        const unsigned char *v = sqlite3_value_text(argv[0]);
        // Apply passed parameters to index
    }
    return SQLITE_OK;
}

/*
 * Advances to the next found object
 */
static int flexiEavNext(sqlite3_vtab_cursor *pCursor)
{
    struct flexi_vtab_cursor *cur = (void *) pCursor;
    int result = sqlite3_step(cur->pObjectIterator);
    if (result == SQLITE_DONE)
    {
        cur->bEof = 1;
        return SQLITE_OK;
    }

    if (result == SQLITE_ROW)
    {
        cur->lObjectID = sqlite3_column_int64(cur->pObjectIterator, 0);
        cur->iReadCol = 0;
        return SQLITE_OK;
    }

    return result;
}

/*
 * Returns 0 if EOF is not reached yet. 1 - if EOF (all rows processed)
 */
static int flexiEavEof(sqlite3_vtab_cursor *pCursor)
{
    struct flexi_vtab_cursor *cur = (void *) pCursor;
    return cur->bEof;
}

/*
 * Returns value for the column at position iCol (starting from 0).
 * Can use the following APIs:
sqlite3_result_blob()
sqlite3_result_double()
sqlite3_result_int()
sqlite3_result_int64()
sqlite3_result_null()
sqlite3_result_text()
sqlite3_result_text16()
sqlite3_result_text16le()
sqlite3_result_text16be()
sqlite3_result_zeroblob()
 *
 */
static int flexiEavColumn(sqlite3_vtab_cursor *pCursor, sqlite3_context *pContext, int iCol)
{
    struct flexi_vtab_cursor *cur = (void *) pCursor;

    // First, check if column has been already loaded
    if (cur->iReadCol >= iCol + 1)
    {
        sqlite3_result_value(pContext, cur->pCols[iCol].pVal);
        return SQLITE_OK;
    }

    sqlite3_step(cur->pPropertyIterator);

    // Map column number to property ID
    return SQLITE_OK;
}

/*
 * Returns object ID into pRowID
 */
static int flexiEavRowId(sqlite3_vtab_cursor *pCursor, sqlite_int64 *pRowid)
{
    struct flexi_vtab_cursor *cur = (void *) pCursor;
    *pRowid = cur->lObjectID;
    return SQLITE_OK;
}

/*
 * Performs INSERT, UPDATE and DELETE operations
 * argc == 1 -> DELETE, argv[0] - object ID or SQL_NULL
 * argv[1]: SQL_NULL ? allocate object ID and return it in pRowid : ID for new object
 *
 * argc = 1
The single row with rowid equal to argv[0] is deleted. No insert occurs.

argc > 1
argv[0] = NULL
A new row is inserted with a rowid argv[1] and column values in argv[2] and following.
 If argv[1] is an SQL NULL, the a new unique rowid is generated automatically.

argc > 1
argv[0] ≠ NULL
argv[0] = argv[1]
The row with rowid argv[0] is updated with new values in argv[2] and following parameters.

argc > 1
argv[0] ≠ NULL
argv[0] ≠ argv[1]
The row with rowid argv[0] is updated with rowid argv[1] and new values in argv[2] and following parameters.
 This will occur when an SQL statement updates a rowid, as in the statement:

UPDATE table SET rowid=rowid+1 WHERE ...;
 */
static int flexiEavUpdate(sqlite3_vtab *pVTab, int argc, sqlite3_value **argv, sqlite_int64 *pRowid)
{
    return SQLITE_OK;
}

/*
 * Renames class to a new name (zNew)
 */
static int flexiEavRename(sqlite3_vtab *pVtab, const char *zNew)
{
    struct flexi_vtab *pTab = (void *) pVtab;
    const char *zSql = "insert or replace into [.names] (NameID, [Value]) select NameID, $Value from [.names] where Value = $Value limit 1;" \
        "update [.classes] set NameID = $NameID where ClassID = $ClassID;";

    const char *zErrMsg;
    sqlite3_stmt *pStmt;
    int result = sqlite3_prepare_v2(pTab->db, zSql, (int) strlen(zSql), &pStmt, &zErrMsg);
    if (result == SQLITE_OK)
    {
// TODO sqlite3_bind_int64(pStmt, 0,)
    }

    return result;
}


/* The methods of the json_each virtual table */
static sqlite3_module flexiEavModule = {
        0,                         /* iVersion */
        flexiEavCreate,            /* xCreate */
        flexiEavConnect,           /* xConnect */
        flexiEavBestIndex,         /* xBestIndex */
        flexiEavDisconnect,        /* xDisconnect */
        flexiEavDestroy,           /* xDestroy */
        flexiEavOpen,              /* xOpen - open a cursor */
        flexiEavClose,             /* xClose - close a cursor */
        flexiEavFilter,            /* xFilter - configure scan constraints */
        flexiEavNext,              /* xNext - advance a cursor */
        flexiEavEof,               /* xEof - check for end of scan */
        flexiEavColumn,            /* xColumn - read data */
        flexiEavRowId,             /* xRowid - read data */
        flexiEavUpdate,            /* xUpdate */
        0,                         /* xBegin */
        0,                         /* xSync */
        0,                         /* xCommit */
        0,                         /* xRollback */
        0,                         /* xFindMethod */
        flexiEavRename,            /* xRename */
        0,                         /* xSavepoint */
        0,                         /* xRelease */
        0                          /* xRollbackTo */
};

static void flexiEavModuleDestroy(void *data)
{

}

int sqlite3_flexieav_vtable_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
)
{
    void *data = NULL; // TODO
    int result = sqlite3_create_module_v2(db, "flexi_eav", &flexiEavModule, data, flexiEavModuleDestroy);
    return result;
}