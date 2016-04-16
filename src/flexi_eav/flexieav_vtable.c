//
// Created by slanska on 2016-04-08.
//

#include <string.h>
#include <printf.h>
#include <float.h>
#include <assert.h>
#include "../../lib/sqlite/sqlite3ext.h"
#include "../../src/misc/json1.h"
#include "./flexi_eav.h"
#include "../misc/regexp.h"

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
    struct ReCompiled *pRegexCompiled;
    int type;
    char *regex;
    double maxValue;
    double minValue;
    int maxLength;
    int minOccurences;
    int maxOccurences;
    sqlite3_value *defaultValue;
    char *zName;
    short int xRole;
    char bIndexed;
    char bUnique;
    char bFullTextIndex;
    int xCtlv;
};

/*
 * SQLite statements used for flexi_eav management
 *
 */
#define STMT_DEL_OBJ            0
#define STMT_UPD_OBJ            1
#define STMT_UPD_PROP           2
#define STMT_INS_OBJ            3
#define STMT_INS_PROP           4
#define STMT_DEL_PROP           5
#define STMT_UPD_OBJ_ID         6
#define STMT_INS_NAME           7
#define STMT_SEL_CLS_BY_NAME    8
#define STMT_SEL_NAME_ID        9
#define STMT_SEL_PROP_ID        10
#define STMT_INS_RTREE          11
#define STMT_UPD_RTREE          12
#define STMT_DEL_RTREE          13
#define STMT_LOAD_CLS           14
#define STMT_LOAD_CLS_PROP      15

// Should be last one in the list
#define STMT_DEL_FTS            20

struct flexi_vtab
{
    sqlite3_vtab base;
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

    char *zHash;
    sqlite3_int64 iNameID;
    int bSystemClass;
    int xCtloMask;
    struct flexi_db_env *pDBEnv;
};

/*
 * Connection wide data and settings
 */
struct flexi_db_env
{
    sqlite3_stmt *pStmts[STMT_DEL_FTS + 1];

};

/*
 *
 */
static void flexi_vtab_prop_free(struct flexi_prop_metadata const *prop)
{
    sqlite3_value_free(prop->defaultValue);
    sqlite3_free(prop->zName);
    sqlite3_free(prop->regex);
    if (prop->pRegexCompiled)
        re_free(prop->pRegexCompiled);
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
    struct sqlite3_vtab_cursor base;

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
#define strReset(SB)         jsonReset(SB)
#define CHECK2(result, label)       if (result != SQLITE_OK) goto label;
#define CHECK_CALL(call)       result = (call); \
        if (result != SQLITE_OK) goto CATCH;
#define CHECK_STMT(call)       result = (call); \
        if (result != SQLITE_DONE && result != SQLITE_ROW) goto CATCH;

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
 * TODO Complete this func
 */
static int prepare_predefined_sql_stmt(struct flexi_db_env *pDBEnv, int idx)
{
    if (pDBEnv->pStmts[idx] == NULL)
    {
        char *zSQL;
        switch (idx)
        {
            case STMT_INS_NAME:
                break;
            case STMT_SEL_CLS_BY_NAME:
                break;
            case STMT_DEL_PROP:
                break;
            case STMT_INS_OBJ:
                break;
            default:
                break;

        }
    }

    return SQLITE_OK;
}

/*
 * Gets name ID by value. Name is expected to exist
 */
static int db_get_name_id(struct flexi_db_env *pDBEnv,
                          const char *zName, sqlite3_int64 *pNameID)
{
    if (pNameID)
    {
        sqlite3_stmt *p = pDBEnv->pStmts[STMT_SEL_NAME_ID];
        assert(p);
        sqlite3_reset(p);
        sqlite3_bind_text(p, 1, zName, -1, NULL);
        int stepRes = sqlite3_step(p);
        if (stepRes != SQLITE_ROW)
            return stepRes;

        *pNameID = sqlite3_column_int64(p, 0);
    }

    return SQLITE_OK;
}

/*
 * Loads class definition from [.classes] and [.class_properties] tables
 * into ppVTab (casted to flexi_vtab).
 * Used by Create and Connect methods
 */
static int flexi_load_class_def(
        sqlite3 *db,
        // User data
        void *pAux,
        const char *zClassName,
        sqlite3_vtab **ppVTab,
        char **pzErr)
{
    int result = SQLITE_OK;

    // Initialize variables
    struct flexi_vtab *vtab = NULL;
    sqlite3_stmt *pGetClsPropStmt = NULL;
    sqlite3_stmt *pGetClassStmt = NULL;
    StringBuilder sbClassDef;

    CHECK_MALLOC(vtab, sizeof(struct flexi_vtab));
    memset(vtab, 0, sizeof(*vtab));

    vtab->pDBEnv = pAux;
    vtab->db = db;

    jsonInit(&sbClassDef, NULL);

    strAppend(&sbClassDef, "create table [");
    strAppend(&sbClassDef, zClassName);
    strAppend(&sbClassDef, "] (");

    *ppVTab = (void *) vtab;

    sqlite3_int64 lClassNameID;
    CHECK_CALL(db_get_name_id(vtab->pDBEnv, zClassName, &lClassNameID));

    // Init property metadata
    const char *zGetClassSQL = "select "
            "ClassID, " // 0
            "NameID, " // 1
            "SystemClass, " // 2
            "ctloMask, " // 3
            "Hash " // 4
            "from [.classes] "
            "where NameID = :1;";
    CHECK_CALL(sqlite3_prepare_v2(db, zGetClassSQL, -1, &pGetClassStmt, NULL));
    sqlite3_bind_int64(pGetClassStmt, 1, lClassNameID);
    result = (sqlite3_step(pGetClassStmt));
    if (result == SQLITE_DONE)
        // No class found. Return error
    {
        result = SQLITE_NOTFOUND;
        *pzErr = "Cannot find Flexilite class"; // TODO inject class name
        goto CATCH;
    }

    if (result != SQLITE_ROW)
        goto CATCH;

    vtab->iClassID = sqlite3_column_int64(pGetClassStmt, 0);
    vtab->iNameID = sqlite3_column_int64(pGetClassStmt, 1);
    vtab->bSystemClass = sqlite3_column_int(pGetClassStmt, 2);
    vtab->xCtloMask = sqlite3_column_int(pGetClassStmt, 3);

    {
        int iHashLen = sqlite3_column_bytes(pGetClassStmt, 4);
        if (iHashLen > 0)
        {
            vtab->zHash = sqlite3_malloc(iHashLen + 1);
            strcpy(vtab->zHash, (char *) sqlite3_column_text(pGetClassStmt, 4));
        }
    }

    const char *zGetClsPropSQL = "select "
            "cp.NameID, " // 0
            "cp.PropertyID, " // 1
            "coalesce(json_extract(c.Data, printf('$.properties.%d.indexed', cp.PropertyID)), 0) as indexed," // 2
            "coalesce(json_extract(c.Data, printf('$.properties.%d.unique', cp.PropertyID)), 0) as [unique]," // 3
            "coalesce(json_extract(c.Data, printf('$.properties.%d.fastTextSearch', cp.PropertyID)), 0) as fastTextSearch," // 4
            "coalesce(json_extract(c.Data, printf('$.properties.%d.role', cp.PropertyID)), 0) as role," // 5
            "coalesce(json_extract(c.Data, printf('$.properties.%d.rules.type', cp.PropertyID)), 0) as [type]," // 6
            "json_extract(c.Data, printf('$.properties.%d.rules.regex', cp.PropertyID)) as regex," // 7
            "coalesce(json_extract(c.Data, printf('$.properties.%d.rules.minOccurences', cp.PropertyID)), 0) as minOccurences," // 8
            "coalesce(json_extract(c.Data, printf('$.properties.%d.rules.maxOccurences', cp.PropertyID)), 1) as maxOccurences," // 9
            "coalesce(json_extract(c.Data, printf('$.properties.%d.rules.maxLength', cp.PropertyID)), 0) as maxLength," // 10
            "json_extract(c.Data, printf('$.properties.%d.rules.minValue', cp.PropertyID)) as minValue, " // 11
            "json_extract(c.Data, printf('$.properties.%d.rules.maxValue', cp.PropertyID)) as maxValue, " // 12
            "json_extract(c.Data, printf('$.properties.%d.defaultValue', cp.PropertyID)) as defaultValue, " // 13
            "(select [Value] from [.names] n where n.NameID = cp.NameID limit 1) as Name," // 14
            "cp.ctlv as ctlv " // 15
            "from [.class_properties] cp "
            "join [.classes] c on cp.ClassID = c.ClassID "
            "where cp.ClassID = :1 order by PropertyID;";
    CHECK_CALL(sqlite3_prepare_v2(db, zGetClsPropSQL, -1, &pGetClsPropStmt, NULL));
    sqlite3_bind_int64(pGetClsPropStmt, 1, vtab->iClassID);

    int nPropIdx = 0;
    do
    {
        int stepResult = sqlite3_step(pGetClsPropStmt);
        if (stepResult == SQLITE_DONE)
            break;
        if (stepResult != SQLITE_ROW)
        {
            result = stepResult;
            goto CATCH;
        }

        if (nPropIdx >= vtab->nPropColsAllocated)
        {
            vtab->nPropColsAllocated += 4;

            int newLen = vtab->nPropColsAllocated * sizeof(*vtab->pProps);
            void *tmpProps = sqlite3_realloc(vtab->pProps, newLen);
            if (tmpProps == NULL)
            {
                result = SQLITE_NOMEM;
                goto CATCH;
            }

            memset(tmpProps + (nPropIdx * sizeof(*vtab->pProps)), 0,
                   sizeof(*vtab->pProps) * (vtab->nPropColsAllocated - nPropIdx));
            vtab->pProps = tmpProps;
        }

        struct flexi_prop_metadata *p = &vtab->pProps[nPropIdx];
        p->iNameID = sqlite3_column_int64(pGetClsPropStmt, 0);
        p->iPropID = sqlite3_column_int64(pGetClsPropStmt, 1);
        p->bIndexed = (char) sqlite3_column_int(pGetClsPropStmt, 2);
        p->bUnique = (char) sqlite3_column_int(pGetClsPropStmt, 3);
        p->bFullTextIndex = (char) sqlite3_column_int(pGetClsPropStmt, 4);
        p->xRole = (short int) sqlite3_column_int(pGetClsPropStmt, 5);
        p->type = sqlite3_column_int(pGetClsPropStmt, 6);

        int iRxLen = sqlite3_column_bytes(pGetClsPropStmt, 7);
        if (iRxLen > 0)
        {
            p->regex = sqlite3_malloc(iRxLen + 1);
            strcpy(p->regex, (char *) sqlite3_column_text(pGetClsPropStmt, 7));
            // Pre-compile regexp expression, if needed

            const char *zRegexErr = re_compile(&p->pRegexCompiled, p->regex, 0);
            if (zRegexErr)
            {
                *pzErr = (char *) zRegexErr;
                result = SQLITE_ERROR;
                goto CATCH;
            }
        }

        // minOccurences
        {
            p->minOccurences = sqlite3_column_int(pGetClsPropStmt, 8);
        }

        // maxOccurences
        {
            p->maxOccurences = sqlite3_column_int(pGetClsPropStmt, 9);
        }

        // maxLength
        {
            p->maxLength = sqlite3_column_int(pGetClsPropStmt, 10);
        }

        // minValue
        {
            p->minValue = sqlite3_column_double(pGetClsPropStmt, 11);
        }

        //  maxValue
        {
            p->maxValue = sqlite3_column_double(pGetClsPropStmt, 12);
        }

        p->defaultValue = sqlite3_value_dup(sqlite3_column_value(pGetClsPropStmt, 13));

        p->zName = sqlite3_malloc(sqlite3_column_bytes(pGetClsPropStmt, 14) + 1);
        strcpy(p->zName, (char *) sqlite3_column_text(pGetClsPropStmt, 14));

        p->xCtlv = sqlite3_column_int(pGetClsPropStmt, 15);

        if (nPropIdx != 0)
        {
            strAppend(&sbClassDef, ",");
        }
        strAppend(&sbClassDef, "[");
        strAppend(&sbClassDef, vtab->pProps[nPropIdx].zName);
        strAppend(&sbClassDef, "]");

        nPropIdx++;

    } while (1);

    vtab->nCols = nPropIdx;

    strAppend(&sbClassDef, ");");

    // Fix strange issue with misplaced terminating zero
    sbClassDef.zBuf[sbClassDef.nUsed] = 0;
    CHECK_CALL(sqlite3_declare_vtab(db, sbClassDef.zBuf));

    // Init property-column map (unsorted)
    CHECK_MALLOC(vtab->pSortedProps, nPropIdx * sizeof(struct flexi_prop_col_map));
    for (int ii = 0; ii < nPropIdx; ii++)
    {
        vtab->pSortedProps[ii].iCol = ii;
        vtab->pSortedProps[ii].iPropID = vtab->pProps[ii].iPropID;
    }

    // Sort prop-col map
    flexi_sort_cols_by_prop_id(vtab);

    result = SQLITE_OK;
    goto FINALLY;

    CATCH:
    flexi_vtab_free(vtab);

    FINALLY:
    strReset(&sbClassDef);
    if (pGetClassStmt)
        sqlite3_finalize(pGetClassStmt);
    if (pGetClsPropStmt)
        sqlite3_finalize(pGetClsPropStmt);

    return result;
}

/*
 * Finds property ID by its class ID and name ID
 */
static int db_get_prop_id_by_class_and_name
        (struct flexi_db_env *pDBEnv,
         sqlite3_int64 lClassID, sqlite3_int64 lPropNameID, sqlite3_int64 *plPropID)
{
    assert(plPropID);

    sqlite3_stmt *p = pDBEnv->pStmts[STMT_SEL_PROP_ID];
    assert(p);
    sqlite3_reset(p);
    sqlite3_bind_int64(p, 1, lClassID);
    sqlite3_bind_int64(p, 2, lPropNameID);
    int stepRes = sqlite3_step(p);
    if (stepRes != SQLITE_ROW)
        return stepRes;

    *plPropID = sqlite3_column_int64(p, 0);

    return SQLITE_OK;
}

/*
 * Ensures that there is given Name in [.names] table.
 * Returns name id in pNameID (if not null)
 */
static int db_insert_name(struct flexi_db_env *pDBEnv, const char *zName, sqlite3_int64 *pNameID)
{
    assert(zName);
    {
        sqlite3_stmt *p = pDBEnv->pStmts[STMT_INS_NAME];
        assert(p);
        sqlite3_reset(p);
        sqlite3_bind_text(p, 1, zName, -1, NULL);
        int stepRes = sqlite3_step(p);
        if (stepRes != SQLITE_DONE)
            return stepRes;
    }

    int result = db_get_name_id(pDBEnv, zName, pNameID);

    return result;
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
    sqlite3_stmt *pExtractProps = NULL;
    sqlite3_stmt *pInsClsStmt = NULL;
    sqlite3_stmt *pInsPropStmt = NULL;
    sqlite3_stmt *pUpdClsStmt = NULL;
    char *zPropName = NULL;
    unsigned char *zPropDefJSON = NULL;
    StringBuilder sbClassDefJSON;

    struct flexi_db_env *pDBEnv = pAux;

    jsonInit(&sbClassDefJSON, NULL);

    strAppend(&sbClassDefJSON, "{\"properties\":{");

    const char *zClassName = argv[2];

    struct flexi_prop_metadata dProp;

    sqlite3_int64 lClassNameID;
    CHECK_CALL(db_insert_name(pDBEnv, zClassName, &lClassNameID));

    // insert into .classes
    {
        const char *zInsClsSQL = "insert into [.classes] (NameID) values (:1);";

        CHECK_CALL(sqlite3_prepare_v2(db, zInsClsSQL, -1, &pInsClsStmt, NULL));
        sqlite3_bind_int64(pInsClsStmt, 1, lClassNameID);
        int stepResult = sqlite3_step(pInsClsStmt);
        if (stepResult != SQLITE_DONE)
        {
            result = stepResult;
            goto CATCH;
        }
    }

    sqlite3_int64 iClassID;
    {
        sqlite3_stmt *p = pDBEnv->pStmts[STMT_SEL_CLS_BY_NAME];
        assert(p);
        sqlite3_reset(p);
        sqlite3_bind_text(p, 1, zClassName, -1, NULL);
        int stepRes = sqlite3_step(p);
        if (stepRes != SQLITE_ROW)
        {
            result = stepRes;
            goto CATCH;
        }

        iClassID = sqlite3_column_int64(p, 0);
    }

    int xCtloMask = 0;

    const char *zInsPropSQL = "insert into [.class_properties] (NameID, ClassID, ctlv) values (:1, :2, :3);";
    CHECK_CALL(sqlite3_prepare_v2(db, zInsPropSQL, -1, &pInsPropStmt, NULL));

    // We expect 1st argument passed (at argv[3]) to be valid JSON which describes class
    // (should follow IClassDefinition specification)

    const char *zExtractPropSQL = "select "
            "coalesce(json_extract(value, '$.indexed'), 0) as indexed," // 0
            "coalesce(json_extract(value, '$.unique'), 0) as [unique]," // 1
            "coalesce(json_extract(value, '$.fastTextSearch'), 0) as fastTextSearch," // 2
            "coalesce(json_extract(value, '$.role'), 0) as role," // 3
            "coalesce(json_extract(value, '$.rules.type'), 0) as type," // 4
            "key as prop_name," // 5
            "value as prop_def" // 6 - Original property definition JSON
            " from json_each(:1, '$.properties');";

    // Need to remove leading and traliling quotes
    int iJSONLen = (int) strlen(argv[3]);
    CHECK_CALL(sqlite3_prepare_v2(db, zExtractPropSQL, -1, &pExtractProps, NULL));
    CHECK_CALL(sqlite3_bind_text(pExtractProps, 1, argv[3] + sizeof(char), iJSONLen - 2, NULL));

    int iPropCnt = 0;
    int iRangeIdxCnt = 0;

    // Load property definitions from JSON
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

        memset(&dProp, 0, sizeof(dProp));
        dProp.bIndexed = (char) sqlite3_column_int(pExtractProps, 0);
        dProp.bUnique = (char) sqlite3_column_int(pExtractProps, 1);
        dProp.bFullTextIndex = (char) sqlite3_column_int(pExtractProps, 2);
        dProp.xRole = (short int) sqlite3_column_int(pExtractProps, 3);
        dProp.type = sqlite3_column_int(pExtractProps, 4);

        sqlite3_free((void *) zPropName);
        sqlite3_free((void *) zPropDefJSON);
        zPropName = sqlite3_malloc(sqlite3_column_bytes(pExtractProps, 5) + 1);
        zPropDefJSON = sqlite3_malloc(sqlite3_column_bytes(pExtractProps, 6) + 1);
        strcpy(zPropName, (const char *) sqlite3_column_text(pExtractProps, 5));
        strcpy((char *) zPropDefJSON, (const char *) sqlite3_column_text(pExtractProps, 6));

        int xCtlv = 0;

        switch (dProp.type)
        {
            // These property types can be searched by range
            case PROP_TYPE_DECIMAL:
            case PROP_TYPE_NUMBER:
            case PROP_TYPE_DATETIME:
            case PROP_TYPE_INTEGER:

                // These property types can be indexed
            case PROP_TYPE_TEXT:
            case PROP_TYPE_BINARY:
            case PROP_TYPE_NAME:
            case PROP_TYPE_ENUM:
            case PROP_TYPE_UUID:
                if (dProp.bUnique || (dProp.xRole & PROP_ROLE_ID) || (dProp.xRole & PROP_ROLE_NAME))
                    xCtlv |= CTLV_UNIQUE_INDEX;
                // Note: no break here;
                if (dProp.bIndexed)
                    xCtlv |= CTLV_INDEX;
                else
                    if (dProp.bFullTextIndex)
                        xCtlv |= CTLV_FULL_TEXT_INDEX;

            case PROP_TYPE_DATE_RANGE:
            case PROP_TYPE_DECIMAL_RANGE:
            case PROP_TYPE_NUMBER_RANGE:
            case PROP_TYPE_INTEGER_RANGE:
                iRangeIdxCnt++;
                break;
        }

        sqlite3_int64 lPropNameID;
        CHECK_CALL(db_insert_name(pDBEnv, zPropName, &lPropNameID));

        {
            sqlite3_reset(pInsPropStmt);
            sqlite3_bind_int64(pInsPropStmt, 1, lPropNameID);
            sqlite3_bind_int64(pInsPropStmt, 2, iClassID);
            sqlite3_bind_int(pInsPropStmt, 3, xCtlv);
            int stepResult = sqlite3_step(pInsPropStmt);
            if (stepResult != SQLITE_DONE)
            {
                result = stepResult;
                goto CATCH;
            }
        }

        // Get new property ID
        sqlite3_int64 iPropID;
        CHECK_CALL(db_get_prop_id_by_class_and_name(pDBEnv, iClassID, lPropNameID, &iPropID));
        if (iPropCnt != 0)
            strAppend(&sbClassDefJSON, ",");
        char sPropID[15];
        sprintf(sPropID, "\"%lld\":", iPropID);
        strAppend(&sbClassDefJSON, sPropID);
        strAppend(&sbClassDefJSON, zPropDefJSON);

        iPropCnt++;
    }

    strAppend(&sbClassDefJSON, "}}");
    sbClassDefJSON.zBuf[sbClassDefJSON.nUsed] = 0;

    // Update class with new JSON data
    const char *zUpdClsSQL = "update [.classes] set Data = :1, ctloMask= :2 where ClassID = :3";
    CHECK_CALL(sqlite3_prepare_v2(db, zUpdClsSQL, -1, &pUpdClsStmt, NULL));
    sqlite3_bind_text(pUpdClsStmt, 1, sbClassDefJSON.zBuf, (int) strlen(sbClassDefJSON.zBuf), NULL);
    sqlite3_bind_int(pUpdClsStmt, 2, xCtloMask);
    sqlite3_bind_int64(pUpdClsStmt, 3, iClassID);
    int updResult = sqlite3_step(pUpdClsStmt);
    if (updResult != SQLITE_DONE)
    {
        result = updResult;
        goto CATCH;
    }

    CHECK_CALL(flexi_load_class_def(db, pAux, zClassName, ppVTab, pzErr));

    result = SQLITE_OK;

    goto FINALLY;

    CATCH:
    // Release resources because of errors (catch)
    printf("%s", sqlite3_errmsg(db));

    FINALLY:
    // Release all temporary resources
    sqlite3_free((void *) zPropName);
    sqlite3_free((void *) zPropDefJSON);
    if (pExtractProps)
        sqlite3_finalize(pExtractProps);
    if (pInsClsStmt)
        sqlite3_finalize(pInsClsStmt);
    if (pUpdClsStmt)
        sqlite3_finalize(pUpdClsStmt);
    if (pInsPropStmt)
        sqlite3_finalize(pInsPropStmt);

    strReset(&sbClassDefJSON);

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
    /*
     *       char *zSql = sqlite3_mprintf("CREATE TABLE x(%s", argv[3]);
      char *zTmp;
      int ii;
      for(ii=4; zSql && ii<argc; ii++){
        zTmp = zSql;
        zSql = sqlite3_mprintf("%s, %s", zTmp, argv[ii]);
        sqlite3_free(zTmp);
     */
    return flexi_load_class_def(db, pAux, argv[2], ppVtab, pzErr);
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
 * Finds best existing index for the given criteria, based on index definition for class' properties.
 * Applies logic similar to what is implemented in rtree extension.
 * There are few search cases (listed from most efficient to least efficient):
 * - lookup by object ID
 * - lookup by indexed unique column
 * - lookup by indexed column
 * - full text search by text column indexed for FTS
 * - linear scan
 *
 *
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

    // TODO "delete from [.classes] where NameID = (select NameID from [.names] where Value = :name limit 1);"
    return SQLITE_OK;
}

/*
 * Starts SELECT on a Flexilite class
 */
static int flexiEavOpen(sqlite3_vtab *pVTab, sqlite3_vtab_cursor **ppCursor)
{
    int result = SQLITE_OK;
    // Cursor will have 2 prepared sqlite statements: 1) find object IDs by property values (either with index or not), 2) to iterate through found objects' properties
    struct flexi_vtab_cursor *cur = NULL;
    CHECK_MALLOC(cur, sizeof(struct flexi_vtab_cursor));

    *ppCursor = (void *) cur;
    memset(cur, 0, sizeof(*cur));

    cur->bEof = 0;
    cur->lObjectID = -1;
    struct flexi_vtab *vtab = (void *) pVTab;
    const char *zObjSql = "select ObjectID, ClassID, ctlo from [.objects] where ClassID = :1;";
    CHECK_CALL(sqlite3_prepare_v2(vtab->db, zObjSql, -1, &cur->pObjectIterator, NULL));

    const char *zPropSql = "select * from [.ref-values] where ObjectID = :1;";
    CHECK_CALL(sqlite3_prepare_v2(vtab->db, zPropSql, -1, &cur->pPropertyIterator, NULL));

    result = SQLITE_OK;
    goto FINALLY;

    CATCH:
    printf("%s", sqlite3_errmsg(vtab->db));

    FINALLY:
    return result;
}

/*
 * Finishes SELECT
 */
static int flexiEavClose(sqlite3_vtab_cursor *pCursor)
{
    struct flexi_vtab_cursor *cur = (void *) pCursor;
    if (cur->pObjectIterator)
        sqlite3_finalize(cur->pObjectIterator);

    if (cur->pPropertyIterator)
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
    struct flexi_vtab_cursor *cur = (void *) pCursor;
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
 * Calculates number of UTF-8 characters in the string.
 * Source: http://stackoverflow.com/questions/5117393/utf-8-strings-length-in-linux-c
 */
static int get_utf8_len(const unsigned char *s)
{
    int i = 0, j = 0;
    while (s[i])
    {
        if ((s[i] & 0xc0) != 0x80) j++;
        i++;
    }
    return j;
}

/*
 * Validates data for the property by iCol index. Returns SQLITE_OK if validation was successfull, or error code
 * otherwise
 */
static int flexi_validate_prop_data(struct flexi_vtab *pVTab, int iCol, sqlite3_value *v)
{
    // Assume error
    int result = SQLITE_ERROR;

    assert(iCol >= 0 && iCol < pVTab->nCols);
    struct flexi_prop_metadata *pProp = &pVTab->pProps[iCol];

    // Required
    if (pProp->minOccurences > 0 && sqlite3_value_type(v) == SQLITE_NULL)
    {
        // TODO set name
        pVTab->base.zErrMsg = "Column %s is required";
        goto CATCH;
    }

    int t = sqlite3_value_type(v);
    switch (pProp->type)
    {
        case PROP_TYPE_BINARY:
            // Do nothing?
            break;

        case PROP_TYPE_DATETIME:
        {
            // Convert from string?
            break;
        }

        case PROP_TYPE_ENUM:
        {
            // Check if value is in the list
// TODO
            break;
        }

        case PROP_TYPE_DECIMAL:
        case PROP_TYPE_INTEGER:
        {
            // Check range
            sqlite3_int64 i = sqlite3_value_int64(v);
            double d = (double) i;

            // Check minValue, maxValue
            if (d < pProp->minValue || d > pProp->maxValue)
            {
                pVTab->base.zErrMsg = "Value is not within range";
                goto CATCH;
            }

            break;
        }

        case PROP_TYPE_NUMBER:
        {
            double d = sqlite3_value_double(v);
            if (t != SQLITE_FLOAT)
            {
                // TODO
                t = sqlite3_value_numeric_type(v);

            }

            // Check minValue, maxValue
            if (d < pProp->minValue || d > pProp->maxValue)
            {
                pVTab->base.zErrMsg = "Value is not within range";
                goto CATCH;
            }
        }
            break;

        case PROP_TYPE_NAME:
        case PROP_TYPE_TEXT:
        {
            const unsigned char *str = NULL;

            // for NAME, check if value type is integer and there is name in database
            // with matching NameID. In this case,

            // maxLength, if applicable
            if (pProp->maxLength > 0)
            {
                // TODO For NAME get actual value and compare
                str = sqlite3_value_text(v);
                int len = get_utf8_len(str);
                if (len > pProp->maxLength)
                {
                    pVTab->base.zErrMsg = "Too long value for column %s";
                    goto CATCH;
                }
            }

            // regex, if applicable
            if (pProp->regex)
            {
                if (str == NULL)
                    str = sqlite3_value_text(v);
                CHECK_CALL(re_match(pProp->pRegexCompiled, str, -1));
            }
        }

            //

            break;

        default:
            break;
    }

    result = SQLITE_OK;
    goto FINALLY;
    CATCH:

    FINALLY:
    return result;
}

/*
 * Validates property values for the row to be inserted/updated
 * Returns SQLITE_OK if validation passed, or error code otherwise.
 * In case of error pVTab->base.zErrMsg will be set to the exact error message
 */
static int flexi_validate(struct flexi_vtab *pVTab, int argc, sqlite3_value **argv)
{
    int result = SQLITE_OK;

    for (int ii = 2; ii < argc; ii++)
    {
        CHECK_CALL(flexi_validate_prop_data(pVTab, ii - 2, argv[ii]));
    }

    goto FINALLY;
    CATCH:
    //
    FINALLY:
    //
    return result;
}

/*
 *
 */
static int flexi_upsert_props(struct flexi_vtab *pVTab, sqlite3_int64 lObjectID,
                              sqlite3_stmt *pStmt, int bDeleteNulls, int argc, sqlite3_value **argv)
{
    int result = SQLITE_OK;

    CHECK_CALL(flexi_validate(pVTab, argc, argv));

    for (int ii = 2; ii < argc; ii++)
    {
        if (argv[ii] != NULL && sqlite3_value_type(argv[ii]) != SQLITE_NULL)
        {
            CHECK_CALL(sqlite3_reset(pStmt));
            sqlite3_bind_int64(pStmt, 1, lObjectID);
            sqlite3_bind_int64(pStmt, 2, pVTab->pProps[ii - 2].iPropID);
            sqlite3_bind_int(pStmt, 3, 0);
            sqlite3_bind_int(pStmt, 4, pVTab->pProps[ii - 2].xCtlv);
            sqlite3_bind_value(pStmt, 5, argv[ii]);
            CHECK_STMT(sqlite3_step(pStmt));
        }
        else
        {
            if (bDeleteNulls)
            {
                sqlite3_stmt *pDelProp = pVTab->pDBEnv->pStmts[STMT_DEL_PROP];
                CHECK_CALL(sqlite3_reset(pDelProp));
                sqlite3_bind_int64(pDelProp, 1, lObjectID);
                sqlite3_bind_int64(pDelProp, 2, pVTab->pProps[ii - 2].iPropID);
                sqlite3_bind_int(pDelProp, 3, 0);
                CHECK_STMT(sqlite3_step(pDelProp));
            }
        }
    }

    result = SQLITE_OK;
    goto FINALLY;

    CATCH:

    if (pVTab->base.zErrMsg == NULL)
    {

    }

    FINALLY:
    return result;
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
    int result = SQLITE_OK;
    struct flexi_vtab *vtab = (struct flexi_vtab *) pVTab;

    if (argc == 1)
        // Delete
    {
        if (sqlite3_value_type(argv[0]) == SQLITE_NULL)
            // Nothing to delete. Exit
        {
            return SQLITE_OK;
        }

        sqlite3_int64 lOldID = sqlite3_value_int64(argv[0]);
        sqlite3_stmt *pDel = vtab->pDBEnv->pStmts[STMT_DEL_OBJ];
        assert(pDel);
        CHECK_CALL(sqlite3_reset(pDel));
        sqlite3_bind_int64(pDel, 1, lOldID);
        CHECK_STMT(sqlite3_step(pDel));

        sqlite3_stmt *pDelRtree = vtab->pDBEnv->pStmts[STMT_DEL_RTREE];
        assert(pDelRtree);
        CHECK_CALL(sqlite3_reset(pDelRtree));
        sqlite3_bind_int64(pDelRtree, 1, lOldID);
        CHECK_STMT(sqlite3_step(pDelRtree));
    }
    else
    {
        if (sqlite3_value_type(argv[0]) == SQLITE_NULL)
            // Insert new row
        {
            sqlite3_stmt *pInsObj = vtab->pDBEnv->pStmts[STMT_INS_OBJ];
            assert(pInsObj);

            CHECK_CALL(sqlite3_reset(pInsObj));
            sqlite3_bind_value(pInsObj, 1, argv[1]); // Object ID, normally null
            sqlite3_bind_int64(pInsObj, 2, vtab->iClassID);
            sqlite3_bind_int(pInsObj, 3, vtab->xCtloMask);

            CHECK_STMT(sqlite3_step(pInsObj));

            if (sqlite3_value_type(argv[1]) == SQLITE_NULL)
            {
                *pRowid = sqlite3_last_insert_rowid(vtab->db);
            }
            else *pRowid = sqlite3_value_int64(argv[1]);

            sqlite3_stmt *pInsProp = vtab->pDBEnv->pStmts[STMT_INS_PROP];
            CHECK_CALL(flexi_upsert_props(vtab, *pRowid, pInsProp, 0, argc, argv));
        }
        else
        {
            sqlite3_int64 lNewID = sqlite3_value_int64(argv[1]);
            *pRowid = lNewID;
            if (argv[0] != argv[1])
                // Special case - Object ID update
            {
                sqlite3_int64 lOldID = sqlite3_value_int64(argv[0]);

                sqlite3_stmt *pUpdObjID = vtab->pDBEnv->pStmts[STMT_UPD_OBJ_ID];
                CHECK_CALL(sqlite3_reset(pUpdObjID));
                sqlite3_bind_int64(pUpdObjID, 1, lNewID);
                sqlite3_bind_int64(pUpdObjID, 2, vtab->iClassID);
                sqlite3_bind_int64(pUpdObjID, 3, lOldID);
                CHECK_STMT(sqlite3_step(pUpdObjID));
            }

            sqlite3_stmt *pUpdProp = vtab->pDBEnv->pStmts[STMT_UPD_PROP];
            CHECK_CALL(flexi_upsert_props(vtab, *pRowid, pUpdProp, 1, argc, argv));
        }
    }

    result = SQLITE_OK;
    goto FINALLY;

    CATCH:
    printf("%s", sqlite3_errmsg(vtab->db));

    FINALLY:

    return result;
}

/*
 * Renames class to a new name (zNew)
 */
static int flexiEavRename(sqlite3_vtab *pVtab, const char *zNew)
{
    int result = SQLITE_OK;
    struct flexi_vtab *pTab = (void *) pVtab;
    assert(pTab->iClassID != 0);

    sqlite3_int64 lNewNameID;
    CHECK_CALL(db_insert_name(pTab->pDBEnv, zNew, &lNewNameID));
    const char *zSql = "update [.classes] set NameID = :1 "
            "where ClassID = :2;";

    const char *zErrMsg;
    sqlite3_stmt *pStmt;
    CHECK_CALL(sqlite3_prepare_v2(pTab->db, zSql, -1, &pStmt, &zErrMsg));
    sqlite3_bind_int64(pStmt, 1, lNewNameID);
    sqlite3_bind_int64(pStmt, 2, pTab->iClassID);
    CHECK_CALL(sqlite3_step(pStmt));
    goto FINALLY;

    CATCH:

    FINALLY:

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
    struct flexi_db_env *pDBEnv = data;

    // Release prepared SQL statements
    for (int ii = 0; ii <= STMT_DEL_FTS; ii++)
    {
        if (pDBEnv->pStmts[ii])
            sqlite3_finalize(pDBEnv->pStmts[ii]);
    }
    sqlite3_free(data);
}

int sqlite3_flexieav_vtable_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
)
{
    int result = SQLITE_OK;
    struct flexi_db_env *data = NULL;
    // Init connection wide settings (prepared statements etc.)
    CHECK_MALLOC(data, sizeof(*data));
    memset(data, 0, sizeof(*data));

    const char *zDelObjSQL = "delete from [.objects] where ObjectID = :1;";
    CHECK_CALL(sqlite3_prepare_v2(db, zDelObjSQL, -1, &data->pStmts[STMT_DEL_OBJ], NULL));

    const char *zInsObjSQL = "insert into [.objects] (ObjectID, ClassID, ctlo) values (:1, :2, :3); "
            "select last_insert_rowid();";
    CHECK_CALL(sqlite3_prepare_v2(db, zInsObjSQL, -1, &data->pStmts[STMT_INS_OBJ], NULL));

    const char *zInsPropSQL = "insert into [.ref-values] (ObjectID, PropertyID, PropIndex, ctlv, [Value])"
            " values (:1, :2, :3, :4, :5);";
    CHECK_CALL(sqlite3_prepare_v2(db, zInsPropSQL, -1, &data->pStmts[STMT_INS_PROP], NULL));

    const char *zUpdPropSQL = "insert or replace into [.ref-values] (ObjectID, PropertyID, PropIndex, ctlv, [Value])"
            " values (:1, :2, :3, :4, :5);";
    CHECK_CALL(sqlite3_prepare_v2(db, zUpdPropSQL, -1, &data->pStmts[STMT_UPD_PROP], NULL));

    const char *zDelPropSQL = "delete from [.ref-values] where ObjectID = :1 and PropertyID = :2 and PropIndex = :3;";
    CHECK_CALL(sqlite3_prepare_v2(db, zDelPropSQL, -1, &data->pStmts[STMT_DEL_PROP], NULL));

    const char *zInsNameSQL = "insert or replace into [.names] ([Value], NameID)"
            " values (:1, (select NameID from [.names] where Value = :1 limit 1));";
    CHECK_CALL(sqlite3_prepare_v2(db, zInsNameSQL, -1, &data->pStmts[STMT_INS_NAME], NULL));

    CHECK_CALL(sqlite3_prepare_v2(
            db,
            "select ClassID from [.classes] where NameID = (select NameID from [.names] where [Value] = :1 limit 1);",
            -1, &data->pStmts[STMT_SEL_CLS_BY_NAME], NULL));

    CHECK_CALL(sqlite3_prepare_v2(
            db,
            "select NameID from [.names] where [Value] = :1;",
            -1, &data->pStmts[STMT_SEL_NAME_ID], NULL));

    CHECK_CALL(sqlite3_prepare_v2(
            db,
            "select PropertyID from [.class_properties] where ClassID = :1 and NameID = :2;",
            -1, &data->pStmts[STMT_SEL_PROP_ID], NULL));

    CHECK_CALL(sqlite3_prepare_v2(
            db,
            "insert into [.range_data] ([ObjectID], [ClassID], [ClassID^], [A], [A^], [B], [B^], [C], [C^], [D], [D^]) values "
                    "(:1, :2, :2, :3, :4, :5, :6, :7, :8, :9, :10);",
            -1, &data->pStmts[STMT_INS_RTREE], NULL));

    CHECK_CALL(sqlite3_prepare_v2(
            db, "update [.range_data] set ([ClassID] = :2, [ClassID^] = :2, [A] = :3, [A^] = :4, [B] = :5, [B^] = :6, "
                    "[C] = :7, [C^] = :8, [D] = :9, [D^] = :10) where ObjectID = :1;",
            -1, &data->pStmts[STMT_UPD_RTREE], NULL));

    CHECK_CALL(sqlite3_prepare_v2(
            db, "delete from [.range_data] where ObjectID = :1;",
            -1, &data->pStmts[STMT_DEL_RTREE], NULL));

//    const char *zUpdObjIdSQL = "update [.objects] set ObjectID = :1, ClassID = :2 where ObjectID = :3;";
//    CHECK_CALL(sqlite3_prepare_v2(db, zUpdObjIdSQL, -1, &data->pStmts[STMT_UPD_OBJ_ID], NULL));

    // Init module
    CHECK_CALL(sqlite3_create_module_v2(db, "flexi_eav", &flexiEavModule, data, flexiEavModuleDestroy));

    result = SQLITE_OK;
    goto FINALLY;

    CATCH:
    flexiEavModuleDestroy(data);

    FINALLY:
    return result;
}