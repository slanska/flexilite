//
// Created by slanska on 2016-04-08.
//

#include <string.h>
#include <printf.h>
#include <assert.h>
#include "../../lib/sqlite/sqlite3ext.h"
#include "./flexi_eav.h"
#include "../misc/regexp.h"
#include "../fts/fts3Int.h"

SQLITE_EXTENSION_INIT3

/*
 * Internally used structures, subclassed from SQLite structs
 */

//struct flexi_prop_col_map
//{
//    sqlite3_int64 iPropID;
//    int iCol;
//};

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

    /*
     * 1-8: column is mapped to .range_data columns (1 = A0, 2 = A1, 3 = B0 and so on)
     * 0: not mapped
     */
    unsigned char cRangeColumn;

    /*
     * if not 0x00, mapped to a fixed column in [.objects] table (A-P)
     */
    unsigned char cColMapped;

    /*
     * 0 - no range column
     * 1 - low range bound
     * 2 - high range bound
     */
    unsigned char cRngBound;
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
    //struct flexi_prop_col_map *pSortedProps;

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
    int nRefCount;
    sqlite3_stmt *pStmts[STMT_DEL_FTS + 1];

    /*
     * In-memory database used for certain operations, e.g. MATCH function on non-FTS indexed columns.
     * Lazy-opened and initialized on demand, on first attempt to use it.
     */
    sqlite3 *pMemDB;

    /*
     * Prepared SQL statement used by MATCH function on non-FTS indexed columns to insert temporary rows
     * into full text index table
     */
    sqlite3_stmt *pMatchFuncInsStmt;

    /*
     * Prepared SQL statement used by MATCH function on non-FTS indexed columns to select temporary rows
     * from full text index table
     */
    sqlite3_stmt *pMatchFuncSelStmt;
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
//static void flexi_sort_cols_by_prop_id(struct flexi_vtab *vtab)
//{
//    for (int i = 0; i < vtab->nCols; i++)
//    {
//        for (int j = 0; j < (vtab->nCols - i - 1); j++)
//        {
//            if (vtab->pSortedProps[j].iPropID > vtab->pSortedProps[j + 1].iPropID)
//            {
//                struct flexi_prop_col_map temp = vtab->pSortedProps[j];
//                vtab->pSortedProps[j] = vtab->pSortedProps[j + 1];
//                vtab->pSortedProps[j + 1] = temp;
//            }
//        }
//    }
//}

/*
 * Performs binary search on sorted array of propertyID-column index map.
 * Returns index in vtab->pCols array or -1 if not found
 */
//static int flex_get_col_idx_by_prop_id(struct flexi_vtab *vtab, sqlite3_int64 iPropID)
//{
//    int low = 1;
//    int mid;
//    int high = vtab->nCols;
//    do
//    {
//        mid = (low + high) / 2;
//        if (iPropID < vtab->pSortedProps[mid].iPropID)
//            high = mid - 1;
//        else
//            if (iPropID > vtab->pSortedProps[mid].iPropID)
//                low = mid + 1;
//    } while (iPropID != vtab->pSortedProps[mid].iPropID && low <= high);
//    if (iPropID == vtab->pSortedProps[mid].iPropID)
//    {
//        return mid;
//    }
//
//    return -1;
//}

struct flexi_vtab_cursor
{
    struct sqlite3_vtab_cursor base;

    /*
     * This statement will be used for navigating through object list.
     * Depending on filter, query may vary
     */
    sqlite3_stmt *pObjectIterator;

    /*
     * This statement will be used to iterating through properties of object (by its ID)
     */
    sqlite3_stmt *pPropertyIterator;
    sqlite3_int64 lObjectID;

    /*
     * Actually fetched number of column values.
     * Reset to 0 on every next object fetch
     */
    int iReadCol;

    /*
     * Array of retrieved column data, by column index as it is defined in pVTab->pProps
     */
    sqlite3_value **pCols;

    /*
     * Indicator of end of file
     * May have 3 values:
     * -1: Next was never called. Assume Eof not reached
     * 0: Next was called, not Eof reached
     * 1: Next was called and Eof was reached
     */
    int iEof;
};

// Utility macros
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
            for (int idx = 0; idx < vtab->nCols; idx++)
            {
                flexi_vtab_prop_free(&vtab->pProps[idx]);
            }
        }

//        sqlite3_free(vtab->pSortedProps);
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
 * Initialized range bound computed column based on base range property and bound
 * @pRngProp - pointer to base range property
 * @iBound - bound shift, 1 for low bound, 2 - for high bound
 */
static void init_range_column(struct flexi_prop_metadata *pRngProp, unsigned char cBound)
{
    assert(cBound == 1 || cBound == 2);
    struct flexi_prop_metadata *pBound = pRngProp + cBound;

    // We do not need all attributes from original property. Just key ones
    pBound->cRngBound = cBound;
    pBound->iPropID = pRngProp->iPropID;
    pBound->type = pRngProp->type;
    pBound->zName = sqlite3_mprintf("%s_%d", pRngProp->zName, cBound - 1);

    // Rest of attributes can be retrieved from base range property by using cRngBound as shift
}

/*
 * Initializes database connection wide SQL statements
 */
static int flexi_prepare_db_statements(sqlite3 *db, void *aux_data)
{
    int result = SQLITE_OK;

    struct flexi_db_env *data = aux_data;

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
            "insert into [.range_data] ([ObjectID], [ClassID], [ClassID_1], [A], [A_1], [B], [B_1], [C], [C_1], [D], [D_1]) values "
                    "(:1, :2, :2, :3, :4, :5, :6, :7, :8, :9, :10);",
            -1, &data->pStmts[STMT_INS_RTREE], NULL));

    CHECK_CALL(sqlite3_prepare_v2(
            db,
            "update [.range_data] set [ClassID] = :2, [ClassID_1] = :2, [A] = :3, [A_1] = :4, [B] = :5, [B_1] = :6, "
                    "[C] = :7, [C_1] = :8, [D] = :9, [D_1] = :10 where ObjectID = :1;",
            -1, &data->pStmts[STMT_UPD_RTREE], NULL));

    CHECK_CALL(sqlite3_prepare_v2(
            db, "delete from [.range_data] where ObjectID = :1;",
            -1, &data->pStmts[STMT_DEL_RTREE], NULL));

    goto FINALLY;
    CATCH:
    FINALLY:
    return result;
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
    char *sbClassDef = sqlite3_mprintf("create table [%s] (", zClassName);

    CHECK_MALLOC(vtab, sizeof(struct flexi_vtab));
    memset(vtab, 0, sizeof(*vtab));

    vtab->pDBEnv = pAux;

    if (vtab->pDBEnv->nRefCount == 0)
    {
        CHECK_CALL(flexi_prepare_db_statements(db, vtab->pDBEnv));
    }

    vtab->pDBEnv->nRefCount++;
    vtab->db = db;

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

        int iType = sqlite3_column_int(pGetClsPropStmt, 6);

        int iNewColCnt = nPropIdx;

        if (iNewColCnt >= vtab->nPropColsAllocated)
        {
            vtab->nPropColsAllocated = iNewColCnt + 4;

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
        p->type = iType;

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
            void *pTmp = sbClassDef;
            sbClassDef = sqlite3_mprintf("%s,", pTmp);
            sqlite3_free(pTmp);
        }

        const char *zType = NULL;
        switch (iType)
        {
            case PROP_TYPE_UUID:
            case PROP_TYPE_BINARY:
                zType = "BLOB";
                break;

            case PROP_TYPE_NAME:
            case PROP_TYPE_TEXT:
                zType = "TEXT";
                break;

            case PROP_TYPE_DECIMAL:
            case PROP_TYPE_NUMBER:
                zType = "FLOAT";
                break;

            case PROP_TYPE_ENUM:
            case PROP_TYPE_INTEGER:
            case PROP_TYPE_BOOLEAN:
                zType = "INTEGER";
                break;

            case PROP_TYPE_JSON:
                zType = "JSON1";
                break;

            case PROP_TYPE_DATETIME:
                zType = "FLOAT";
                break;

            default:
                zType = "";
                break;
        }

        {
            void *pTmp = sbClassDef;
            sbClassDef = sqlite3_mprintf("%s[%s] %s", pTmp, vtab->pProps[nPropIdx].zName, zType);
            sqlite3_free(pTmp);
        }

        nPropIdx++;

    } while (1);

    vtab->nCols = nPropIdx;

    {
        void *pTmp = sbClassDef;
        sbClassDef = sqlite3_mprintf("%s);", pTmp);
        sqlite3_free(pTmp);
    }

    // Fix strange issue with misplaced terminating zero
    CHECK_CALL(sqlite3_declare_vtab(db, sbClassDef));

    result = SQLITE_OK;
    goto FINALLY;

    CATCH:
    flexi_vtab_free(vtab);

    FINALLY:
    sqlite3_free(sbClassDef);
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
    unsigned char *zPropDefJSON = NULL;
    char *sbClassDefJSON = sqlite3_mprintf("{\"properties\":{");

    struct flexi_db_env *pDBEnv = pAux;

    const char *zClassName = argv[2];

    struct flexi_prop_metadata dProp;
    memset(&dProp, 0, sizeof(dProp));

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

    const char *zInsPropSQL = "insert into [.class_properties] (NameID, ClassID, ctlv, ctlvPlan)"
            " values (:1, :2, :3, :4);";
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

        sqlite3_free((void *) zPropDefJSON);
        sqlite3_free(dProp.zName);
        dProp.zName = sqlite3_malloc(sqlite3_column_bytes(pExtractProps, 5) + 1);
        zPropDefJSON = sqlite3_malloc(sqlite3_column_bytes(pExtractProps, 6) + 1);
        strcpy(dProp.zName, (const char *) sqlite3_column_text(pExtractProps, 5));
        strcpy((char *) zPropDefJSON, (const char *) sqlite3_column_text(pExtractProps, 6));

        // Property control flags which regulate actual indexing and other settings
        int xCtlv = 0;

        // Planned (postponed for future) property control flags which will be applied later
        // when enough statistics accumulated about best index strategy.
        // Typically, this will happen when database size reaches few megabytes and 1K-5K records
        // On smaller databases there is no real point to apply indexing to the full extent
        // Plus, in the database schema lifetime initial period is usually associated with heavy refactoring
        // and data restructuring.
        // Taking into account these 2 considerations, we will remember user settings for desired indexing
        // (in ctlvPlan) but currently apply only settings for unique values (as it is mostly constraint, rather
        // than indexing)
        int xCtlvPlan = 0;

        switch (dProp.type)
        {
            // These property types can be searched by range, can be indexed and can be unique
            case PROP_TYPE_DECIMAL:
            case PROP_TYPE_NUMBER:
            case PROP_TYPE_DATETIME:
            case PROP_TYPE_INTEGER:

                // These property types can be indexed
            case PROP_TYPE_BINARY:
            case PROP_TYPE_NAME:
            case PROP_TYPE_ENUM:
            case PROP_TYPE_UUID:
                if (dProp.bUnique || (dProp.xRole & PROP_ROLE_ID) || (dProp.xRole & PROP_ROLE_NAME))
                {
                    xCtlv |= CTLV_UNIQUE_INDEX;
                    xCtlvPlan |= CTLV_UNIQUE_INDEX;
                }
                // Note: no break here;

            case PROP_TYPE_TEXT:
                if (dProp.bIndexed && dProp.maxLength <= 30)
                    xCtlvPlan |= CTLV_INDEX;
                if (dProp.bFullTextIndex)
                    xCtlvPlan |= CTLV_FULL_TEXT_INDEX;

                break;
        }

        sqlite3_int64 lPropNameID;
        CHECK_CALL(db_insert_name(pDBEnv, dProp.zName, &lPropNameID));

        {
            sqlite3_reset(pInsPropStmt);
            sqlite3_bind_int64(pInsPropStmt, 1, lPropNameID);
            sqlite3_bind_int64(pInsPropStmt, 2, iClassID);
            sqlite3_bind_int(pInsPropStmt, 3, xCtlv);
            sqlite3_bind_int(pInsPropStmt, 4, xCtlvPlan);
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
        {
            void *pTmp = sbClassDefJSON;
            sbClassDefJSON = sqlite3_mprintf("%s,", pTmp);
            sqlite3_free(pTmp);
        }

        {
            void *pTmp = sbClassDefJSON;
            sbClassDefJSON = sqlite3_mprintf("%s\"%lld\":%s", pTmp, iPropID, zPropDefJSON);
            sqlite3_free(pTmp);
        }

        iPropCnt++;
    }

    {
        void *pTmp = sbClassDefJSON;
        sbClassDefJSON = sqlite3_mprintf("%s}}", pTmp);
        sqlite3_free(pTmp);
    }

    // Update class with new JSON data
    const char *zUpdClsSQL = "update [.classes] set Data = :1, ctloMask= :2 where ClassID = :3";
    CHECK_CALL(sqlite3_prepare_v2(db, zUpdClsSQL, -1, &pUpdClsStmt, NULL));
    sqlite3_bind_text(pUpdClsStmt, 1, sbClassDefJSON, (int) strlen(sbClassDefJSON), NULL);
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

    sqlite3_free((void *) zPropDefJSON);
    sqlite3_free(dProp.zName);

    if (pExtractProps)
        sqlite3_finalize(pExtractProps);
    if (pInsClsStmt)
        sqlite3_finalize(pInsClsStmt);
    if (pUpdClsStmt)
        sqlite3_finalize(pUpdClsStmt);
    if (pInsPropStmt)
        sqlite3_finalize(pInsPropStmt);

    sqlite3_free(sbClassDefJSON);

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
    return flexi_load_class_def(db, pAux, argv[2], ppVtab, pzErr);
}

/*
 * Cleans up Flexilite module environment (prepared SQL statements etc.)
 */
static void flexiCleanUpModuleEnv(struct flexi_db_env *pDBEnv)
{
    // Release prepared SQL statements
    for (int ii = 0; ii <= STMT_DEL_FTS; ii++)
    {
        if (pDBEnv->pStmts[ii])
            sqlite3_finalize(pDBEnv->pStmts[ii]);
    }

    if (pDBEnv->pMatchFuncSelStmt != NULL)
    {
        sqlite3_finalize(pDBEnv->pMatchFuncSelStmt);
        pDBEnv->pMatchFuncSelStmt = NULL;
    }

    if (pDBEnv->pMatchFuncInsStmt != NULL)
    {
        sqlite3_finalize(pDBEnv->pMatchFuncInsStmt);
        pDBEnv->pMatchFuncInsStmt = NULL;
    }

    if (pDBEnv->pMemDB != NULL)
    {
        sqlite3_close(pDBEnv->pMemDB);
        pDBEnv->pMemDB = NULL;
    }

    memset(pDBEnv, 0, sizeof(*pDBEnv));
}

static void flexiEavModuleDestroy(void *data)
{
    flexiCleanUpModuleEnv(data);
    sqlite3_free(data);
}

/*
 *
 */
static int flexiEavDisconnect(sqlite3_vtab *pVTab)
{
    struct flexi_vtab *vtab = (void *) pVTab;

    /*
     * Fix for possible SQLite bug when disposing modules for virtual tables
     * We keep our own counter for number of opened/connected virtual tables, and once
     * this counters gets to 0, we will close all prepared commonly used SQL statements
     */
    vtab->pDBEnv->nRefCount--;
    if (vtab->pDBEnv->nRefCount == 0)
    {
        flexiEavModuleDestroy(vtab->pDBEnv);
    }

    flexi_vtab_free(vtab);
    return SQLITE_OK;
}

/*
** Set the pIdxInfo->estimatedRows variable to nRow. Unless this
** extension is currently being used by a version of SQLite too old to
** support estimatedRows. In that case this function is a no-op.
*/
static void setEstimatedRows(sqlite3_index_info *pIdxInfo, sqlite3_int64 nRow)
{
#if SQLITE_VERSION_NUMBER >= 3008002
    if (sqlite3_libversion_number() >= 3008002)
    {
        pIdxInfo->estimatedRows = nRow;
    }
#endif
}

/*
 * Finds best existing index for the given criteria, based on index definition for class' properties.
 * There are few search strategies. They fall into one of following groups:
 * I) search by rowid (ObjectID)
 * II) search by indexed properties
 * III) search by rtree ranges
 * IV) full text search (via match function)
 * Due to specifics of internal storage of flexilite data (EAV store), these strategies are estimated differently
 * For strategy II every additional search constraint increases estimated cost (since query in this case would be compound from multiple
 * joins)
 * For strategies III and IV it is opposite, every additional constraint reduces estimated cost, since lookup will need
 * to be performed on more restrictive criterias
 * Inside of each strategies there is also rank depending on op code (exact comparison gives less estimated cost, range comparison gives
 * more estimated cost)
 * Here is list of sorted from most efficient to least efficient strategies:
 * 1) lookup by object ID.
 * 2) exact value by indexed or unique column (=)
 * 3) lookup in rtree (by set of fields)
 * 4) range search on indexed or unique column (>, <, >=, <=, <>)
 * 5) full text search by text column indexed for FTS
 * 6) linear scan for exact value
 * 7) linear scan for range
 * 8) linear search for MATCH/REGEX/prefixed LIKE
 *
 *  # of scenario corresponds to idxNum value in output
 *  idxNum will have best found determines format of idxStr.
 *  1) idxStr is not used (null)
 *  2-8) idxStr consists of 6 char tuples with op & column index (+1) encoded
 *  into 2 and 4 hex characters respectively
 *  (e.g. "020003" means EQ operator for column #3). Position of every tuple
 *  corresponds to argvIndex, so that tupleIndex = (argvIndex - 1) * 6
 *   */
static int flexiEavBestIndex(
        sqlite3_vtab *tab,
        sqlite3_index_info *pIdxInfo
)
{
    int ii;
    int result = SQLITE_OK;

    int argCount = 0;

    pIdxInfo->idxStr = NULL;
    for (int jj = 0; jj < pIdxInfo->nConstraint; jj++)
    {
        if (pIdxInfo->aConstraint[jj].usable)
        {
            pIdxInfo->aConstraintUsage[jj].argvIndex = ++argCount;
            void *pTmp = pIdxInfo->idxStr;
            pIdxInfo->idxStr = sqlite3_mprintf("%s%2X|%4X|", pTmp, pIdxInfo->aConstraint[jj].op,
                                               pIdxInfo->aConstraint[jj].iColumn + 1);
            pIdxInfo->needToFreeIdxStr = 1;
            pIdxInfo->idxNum = 1; // TODO
            sqlite3_free(pTmp);
            pIdxInfo->estimatedCost = 0; // TODO

        }
    }

    return result;
}

/*
 * Delete class and all its object data
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

    struct flexi_vtab *vtab = (struct flexi_vtab *) pVTab;
    // Cursor will have 2 prepared sqlite statements: 1) find object IDs by property values (either with index or not), 2) to iterate through found objects' properties
    struct flexi_vtab_cursor *cur = NULL;
    CHECK_MALLOC(cur, sizeof(struct flexi_vtab_cursor));

    *ppCursor = (void *) cur;
    memset(cur, 0, sizeof(*cur));

    cur->iEof = -1;
    cur->lObjectID = -1;

    const char *zPropSql = "select ObjectID, PropertyID, PropIndex, ctlv, [Value] from [.ref-values] "
            "where ObjectID = :1 order by ObjectID, PropertyID, PropIndex;";
    CHECK_CALL(sqlite3_prepare_v2(vtab->db, zPropSql, -1, &cur->pPropertyIterator, NULL));

    result = SQLITE_OK;
    goto FINALLY;

    CATCH:
    printf("%s", sqlite3_errmsg(vtab->db));

    FINALLY:
    return result;
}

/*
 * Cleans up column values left after last Next/Column calls.
 * Return 1 if cur->pCols is not null.
 * Otherwise, 0
 */
static int flexi_free_cursor_values(struct flexi_vtab_cursor *cur)
{
    if (cur->pCols != NULL)
    {
        struct flexi_vtab *vtab = (void *) cur->base.pVtab;
        for (int ii = 0; ii < vtab->nCols; ii++)
        {
            if (cur->pCols[ii] != NULL)
            {
                sqlite3_value_free(cur->pCols[ii]);
                cur->pCols[ii] = NULL;
            }
        }

        return 1;
    }

    return 0;
}

/*
 * Finishes SELECT
 */
static int flexiEavClose(sqlite3_vtab_cursor *pCursor)
{
    struct flexi_vtab_cursor *cur = (void *) pCursor;

    flexi_free_cursor_values(cur);
    sqlite3_free(cur->pCols);

    if (cur->pObjectIterator)
        sqlite3_finalize(cur->pObjectIterator);

    if (cur->pPropertyIterator)
        sqlite3_finalize(cur->pPropertyIterator);
    sqlite3_free(pCursor);
    return SQLITE_OK;
}

/*
 * Advances to the next found object
 */
static int flexiEavNext(sqlite3_vtab_cursor *pCursor)
{
    int result = SQLITE_OK;
    struct flexi_vtab_cursor *cur = (void *) pCursor;
    struct flexi_vtab *vtab = (struct flexi_vtab *) cur->base.pVtab;

    cur->iReadCol = -1;
    result = sqlite3_step(cur->pObjectIterator);
    if (result == SQLITE_DONE)
    {
        cur->iEof = 1;
    }
    else
        if (result == SQLITE_ROW)
        {
            // Cleanup after last record
            if (flexi_free_cursor_values(cur) == 0)
            {
                CHECK_MALLOC(cur->pCols, vtab->nCols * sizeof(sqlite3_value *));
            }
            memset(cur->pCols, 0, vtab->nCols * sizeof(sqlite3_value *));

            cur->lObjectID = sqlite3_column_int64(cur->pObjectIterator, 0);
            cur->iEof = 0;
            CHECK_CALL(sqlite3_reset(cur->pPropertyIterator));
            sqlite3_bind_int64(cur->pPropertyIterator, 1, cur->lObjectID);
        }
        else goto CATCH;

    result = SQLITE_OK;
    goto FINALLY;
    CATCH:
    {
        // Release resources because of errors (catch)
        printf("%s", sqlite3_errmsg(vtab->db));
    }
    FINALLY:
    return result;
}

/*
 * Generates dynamic SQL to find list of object IDs.
 * idxNum may be 0 or 1. When 1, idxStr will have all constraints appended by FindBestIndex.
 * Depending on number of constraint arguments in idxStr generated SQL will have of the following constructs:
 * 1. argc == 1 or all argv are for rtree search
 * 1.1. Unique index: select ObjectID from [.ref-values] where PropertyID = :1 and Value OP :2 and ctlv =
 * 1.2. Index: select ObjectID from [.ref-values] where PropertyID = :1 and Value OP :2 and ctlv =
 * 1.3. Match for full text search with index:
 * select id from [.full_text_data] where PropertyID = :1 and Value match :2
 * 1.4. Linear scan without index:
 * select ObjectID from [.ref-values] where PropertyID = :1 and Value OP :2
 * 1.5. Search by rtree:
 * select id from [.range_data] where ClassID = :1 and A0 OP :2 and A1 OP :3 and...
 *
 * 2.argc > 1
 * General pattern would be:
 * <SQL for argv == 0> intersect <SQL for argv == 1>...
 */
static int flexiEavFilter(sqlite3_vtab_cursor *pCursor, int idxNum, const char *idxStr,
                          int argc, sqlite3_value **argv)
{
    static char *range_columns[] = {"A0", "A1", "B0", "B1", "C0", "C1", "D0", "D1"};

    int result;
    struct flexi_vtab_cursor *cur = (void *) pCursor;
    struct flexi_vtab *vtab = (struct flexi_vtab *) cur->base.pVtab;
    char *zSQL = NULL;

    // Subquery for [.range_data]
    char *zRangeSQL = NULL;

    if (idxNum == 0 || argc == 0)
        // No special index used. Apply linear scan
    {
        CHECK_CALL(sqlite3_prepare_v2(
                vtab->db, "select ObjectID from [.objects] where ClassID = :1;",
                -1, &cur->pObjectIterator, NULL));
        sqlite3_bind_int64(cur->pObjectIterator, 1, vtab->iClassID);
    }
    else
    {
        assert(argc * 8 == strlen(idxStr));

        const char *zIdxTuple = idxStr;
        for (int i = 0; i < argc; i++)
        {
            int op;
            int colIdx;
            sscanf(zIdxTuple, "%2X|%4X|", &op, &colIdx);
            colIdx--;
            zIdxTuple += 8;

            assert(colIdx >= -1 && colIdx < vtab->nCols);

            if (zSQL != NULL)
            {
                void *pTmp = zSQL;
                zSQL = sqlite3_mprintf("%s intersect ", pTmp);
                sqlite3_free(pTmp);
            }

            char *zOp;
            switch (op)
            {
                case SQLITE_INDEX_CONSTRAINT_EQ:
                    zOp = "=";
                    break;
                case SQLITE_INDEX_CONSTRAINT_GT:
                    zOp = ">";
                    break;
                case SQLITE_INDEX_CONSTRAINT_LE:
                    zOp = "<=";
                    break;
                case SQLITE_INDEX_CONSTRAINT_LT:
                    zOp = "<";
                    break;
                case SQLITE_INDEX_CONSTRAINT_GE:
                    zOp = ">=";
                    break;
                default:
                    assert(op == SQLITE_INDEX_CONSTRAINT_MATCH);
                    zOp = "match";
                    break;
            }

            if (colIdx == -1)
                // Search by rowid / ObjectID
            {
                void *pTmp = zSQL;
                zSQL = sqlite3_mprintf(
                        "%sselect ObjectID from [.objects] where ObjectID %s :%d",
                        pTmp, zOp, i + 1);
                sqlite3_free(pTmp);
            }
            else
            {
                struct flexi_prop_metadata *prop = &vtab->pProps[colIdx];
                if (0 /*IS_RANGE_PROPERTY(prop->type)*/)
                    // Special case: range data request
                {
                    assert(prop->cRangeColumn > 0);

                    if (zRangeSQL == NULL)
                    {
                        zRangeSQL = sqlite3_mprintf(
                                "select id from [.range_data] where ClassID0 = %d and ClassID1 = %d ",
                                vtab->iClassID, vtab->iClassID);
                    }
                    void *pTmp = zRangeSQL;
                    zRangeSQL = sqlite3_mprintf("%s and %s %s :%d", pTmp, range_columns[prop->cRangeColumn - 1],
                                                zOp, i + 1);
                    sqlite3_free(pTmp);
                }
                else
                    // Normal column
                {
                    void *zTmp = zSQL;

                    if (op == SQLITE_INDEX_CONSTRAINT_MATCH && prop->bFullTextIndex)
                        // full text search
                    {
                        // TODO Generate lookup on [.full_text_data]
                    }
                    else
                    {
                        zSQL = sqlite3_mprintf
                                ("%sselect ObjectID from [.ref-values] where "
                                         "[PropertyID] = %d and [PropIndex] = 0 and ", zTmp,
                                 prop->iPropID);
                        sqlite3_free(zTmp);
                        if (op != SQLITE_INDEX_CONSTRAINT_MATCH)
                        {
                            zTmp = zSQL;
                            zSQL = sqlite3_mprintf("%s[Value] %s :%d", zTmp, zOp, i + 1);
                            sqlite3_free(zTmp);

                            if (prop->bIndexed)
                            {
                                void *pTmp = zSQL;
                                zSQL = sqlite3_mprintf("%s and (ctlv & %d) = %d", pTmp, CTLV_INDEX, CTLV_INDEX);
                                sqlite3_free(pTmp);
                            }
                            else
                                if (prop->bUnique)
                                {
                                    void *pTmp = zSQL;
                                    zSQL = sqlite3_mprintf("%s and (ctlv & %d) = %d", pTmp, CTLV_UNIQUE_INDEX,
                                                           CTLV_UNIQUE_INDEX);
                                    sqlite3_free(pTmp);
                                }
                        }
                        else
                        {
                            /*
                             * TODO
                             * mem database
                             *
                             */
                            zTmp = zSQL;
                            zSQL = sqlite3_mprintf("%smatch_text(:%d, [Value])", zTmp, i + 1);
                            sqlite3_free(zTmp);
                        }
                    }
                }
            }
        }

        if (zRangeSQL != NULL)
        {
            void *pTmp = zSQL;
            zSQL = sqlite3_mprintf("%s intersect %s", pTmp, zRangeSQL);
            sqlite3_free(pTmp);
        }

        CHECK_CALL(sqlite3_prepare_v2(vtab->db, zSQL, -1, &cur->pObjectIterator, NULL));
        // Bind arguments
        for (int ii = 0; ii < argc; ii++)
        {
            sqlite3_bind_value(cur->pObjectIterator, ii + 1, argv[ii]);
        }
    }

    CHECK_CALL(flexiEavNext(pCursor));

    result = SQLITE_OK;
    goto FINALLY;

    CATCH:

    FINALLY:
    sqlite3_free(zSQL);
    sqlite3_free(zRangeSQL);

    return result;
}

/*
 * Implementation of MATCH function for non-FTS-indexed columns.
 * For the sake of simplicity function uses in-memory FTS4 table with 1 row, which
 * gets replaced for every call. In future this method should be re-implemented
 * and use more efficient direct calls to Sqlite FTS3/4 API. For now,
 * this looks like a reasonable compromize which should work OK for smaller sets
 * of data.
 */
static void matchTextFunction(sqlite3_context *context, int argc, sqlite3_value **argv)
{
    // TODO Update lookup statistics
    int result = SQLITE_OK;
    struct flexi_db_env *pDBEnv = sqlite3_user_data(context);

//    if (pDBEnv == NULL)
//        return;

    assert(pDBEnv != NULL);
    if (pDBEnv->pMemDB == NULL)
    {
        CHECK_CALL(sqlite3_open_v2(":memory:", &pDBEnv->pMemDB, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL));

        CHECK_CALL(sqlite3_exec(pDBEnv->pMemDB, "PRAGMA journal_mode = OFF;"
                                        "create virtual table if not exists [.match_func] using 'fts4' (txt, tokenize=unicode61);", NULL, NULL,
                                NULL));

        CHECK_CALL(
                sqlite3_prepare_v2(pDBEnv->pMemDB, "insert or replace into [.match_func] (docid, txt) values (1, :1);",
                                   -1, &pDBEnv->pMatchFuncInsStmt, NULL));

        CHECK_CALL(
                sqlite3_prepare_v2(pDBEnv->pMemDB, "select docid from [.match_func] where txt match :1;",
                                   -1, &pDBEnv->pMatchFuncSelStmt, NULL));

    }

    sqlite3_reset(pDBEnv->pMatchFuncInsStmt);

    sqlite3_bind_value(pDBEnv->pMatchFuncInsStmt, 1, argv[1]);
    result = sqlite3_step(pDBEnv->pMatchFuncInsStmt);

    sqlite3_reset(pDBEnv->pMatchFuncSelStmt);
    sqlite3_bind_value(pDBEnv->pMatchFuncSelStmt, 1, argv[0]);
    result = sqlite3_step(pDBEnv->pMatchFuncSelStmt);
    sqlite3_int64 lDocID = sqlite3_column_int64(pDBEnv->pMatchFuncSelStmt, 0);
    if (lDocID == 1)
        sqlite3_result_int(context, 1);
    else
        sqlite3_result_int(context, 0);

    result = SQLITE_OK;
    goto FINALLY;
    CATCH:
    sqlite3_result_error(context, NULL, result);
    FINALLY:
    {};
}

/*
 * This is dummy MATCH function which always return 1 (i.e. found).
 * This function is needed as otherwise SQLite wouldn't allow to use MATCH call.
 * Actual implementation is done be FTS4 table (.full_text_data) - for FTS-indexed columns
 * or via linear FTS matching - for not-FTS-indexed columns
 */
static void matchDummyFunction(sqlite3_context *context, int argc, sqlite3_value **argv)
{
    sqlite3_result_int(context, 1);
}
//
// static void likeFunction(sqlite3_context *context, int argc, sqlite3_value **argv)
//{
//    // TODO Update lookup statistics
//    printf("like: %d", argc);
//    sqlite3_result_int(context, 1);
//}
//
//static void regexpFunction(sqlite3_context *context, int argc, sqlite3_value **argv)
//{
//    // TODO Update lookup statistics
//    printf("regexp: %d", argc);
//    sqlite3_result_int(context, 1);
//}

/*
 *
 */
static int flexiFindMethod(
        sqlite3_vtab *pVtab,
        int nArg,
        const char *zName,
        void (**pxFunc)(sqlite3_context *, int, sqlite3_value **),
        void **ppArg
)
{
    // match
    if (strcmp("match", zName) == 0)
    {
        *pxFunc = matchDummyFunction;
        return 1;
    }

//    // like
//    if (strcmp("like", zName) == 0)
//    {
//        *pxFunc = likeFunction;
//        return 1;
//    }
//
//    // glob
//
//    // regexp
//    if (strcmp("regexp", zName) == 0)
//    {
//        *pxFunc = regexpFunction;
//        return 1;
//    }

    return 0;
}

/*
 * Returns 0 if EOF is not reached yet. 1 - if EOF (all rows processed)
 */
static int flexiEavEof(sqlite3_vtab_cursor *pCursor)
{
    struct flexi_vtab_cursor *cur = (void *) pCursor;
    return cur->iEof > 0;
}

/*
 * Returns value for the column at position iCol (starting from 0).
 * Reads column data from ref-values table, filtered by ObjectID and sorted by PropertyID
 * For the sake of better performance, fetches required columns on demand, sequentially.
 *
 */
static int flexiEavColumn(sqlite3_vtab_cursor *pCursor, sqlite3_context *pContext, int iCol)
{
    int result = SQLITE_OK;
    struct flexi_vtab_cursor *cur = (void *) pCursor;

    if (iCol == -1)
    {
        sqlite3_result_int64(pContext, cur->lObjectID);
        goto FINALLY;
    }

    struct flexi_vtab *vtab = (void *) cur->base.pVtab;

    // First, check if column has been already loaded
    while (cur->iReadCol < iCol)
    {
        int colResult = sqlite3_step(cur->pPropertyIterator);
        if (colResult == SQLITE_DONE)
            break;
        if (colResult != SQLITE_ROW)
        {
            result = colResult;
            goto CATCH;
        }
        sqlite3_int64 lPropID = sqlite3_column_int64(cur->pPropertyIterator, 1);
        if (lPropID < vtab->pProps[cur->iReadCol + 1].iPropID)
            continue;

        cur->iReadCol++;
        if (lPropID == vtab->pProps[cur->iReadCol].iPropID)
        {
            sqlite3_int64 lPropIdx = sqlite3_column_int64(cur->pPropertyIterator, 2);

            /*
             * No need in any special verification as we expect columns are storted by property IDs, so
             * we just assume that once column index is OK, we can process this property data
             */

            cur->pCols[cur->iReadCol] = sqlite3_value_dup(sqlite3_column_value(cur->pPropertyIterator, 4));
        }
    }

    if (cur->pCols[iCol] == NULL || sqlite3_value_type(cur->pCols[iCol]) == SQLITE_NULL)
    {
        sqlite3_result_value(pContext, vtab->pProps[iCol].defaultValue);
    }
    else
    {
        sqlite3_result_value(pContext, cur->pCols[iCol]);
    }

    result = SQLITE_OK;
    goto FINALLY;
    CATCH:

    FINALLY:
    // Map column number to property ID
    return result;
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
 * Saves property values for the given object ID
 */
static int flexi_upsert_props(struct flexi_vtab *pVTab, sqlite3_int64 lObjectID,
                              sqlite3_stmt *pStmt, int bDeleteNulls, int argc, sqlite3_value **argv)
{
    int result = SQLITE_OK;

    CHECK_CALL(flexi_validate(pVTab, argc, argv));

    // Values are coming from index 2 (0 and 1 used for object IDs)
    for (int ii = 2; ii < argc; ii++)
    {
        struct flexi_prop_metadata *pProp = &pVTab->pProps[ii - 2];
        sqlite3_value *pVal = argv[ii];

        /*
         * Check if this is range property. If so, actual value can be specified either directly
         * in format 'LoValue|HiValue', or via following computed bound properties.
         * Base range property has priority, so if it is not NULL, it will be used as property value
        */
        int bIsNull = !(argv[ii] != NULL && sqlite3_value_type(argv[ii]) != SQLITE_NULL);
        if (0 /* TODO IS_RANGE_PROPERTY(pProp->type)*/)
        {
            assert(ii + 2 < argc);
            if (bIsNull)
            {
                if (argv[ii + 1] != NULL && sqlite3_value_type(argv[ii + 1]) != SQLITE_NULL
                    && argv[ii + 2] != NULL && sqlite3_value_type(argv[ii + 2]) != SQLITE_NULL)
                {
                    bIsNull = 0;
                }
            }
        }

        // Check if value is not null
        if (!bIsNull)
        {
            // TODO Check if this is a mapped column
            CHECK_CALL(sqlite3_reset(pStmt));
            sqlite3_bind_int64(pStmt, 1, lObjectID);
            sqlite3_bind_int64(pStmt, 2, pProp->iPropID);
            sqlite3_bind_int(pStmt, 3, 0);
            sqlite3_bind_int(pStmt, 4, pProp->xCtlv);

            if (1 /* TODO !IS_RANGE_PROPERTY(pProp->type)*/)
            {
                sqlite3_bind_value(pStmt, 5, pVal);
            }
            else
            {
//                if (argv[ii] == NULL || sqlite3_value_type(argv[ii]) == SQLITE_NULL)
//                {
//                    char *zRange = NULL;
//                    switch (pProp->type)
//                    {
//                        case PROP_TYPE_INTEGER_RANGE:
//                            zRange = sqlite3_mprintf("%li|%li",
//                                                     sqlite3_value_int64(argv[ii + 1]),
//                                                     sqlite3_value_int64(argv[ii + 2]));
//                            break;
//
//                        case PROP_TYPE_DECIMAL_RANGE:
//                        {
//                            double d0 = sqlite3_value_double(argv[ii + 1]);
//                            double d1 = sqlite3_value_double(argv[ii + 2]);
//                            long long i0 = (long long) (d0 * 10000);
//                            long long i1 = (long long) (d1 * 10000);
//                            zRange = sqlite3_mprintf("%li|%li", i0, i1);
//                        }
//
//                            break;
//
//                        default:
//                            zRange = sqlite3_mprintf("%f|%f",
//                                                     sqlite3_value_double(argv[ii + 1]),
//                                                     sqlite3_value_double(argv[ii + 2]));
//                            break;
//                    }
//
//                    sqlite3_bind_text(pStmt, 5, zRange, -1, NULL);
//                    sqlite3_free(zRange);
//                }
//                else
//                {
//                    sqlite3_bind_value(pStmt, 5, pVal);
//                }
//                ii += 2;
            }

            CHECK_STMT(sqlite3_step(pStmt));
        }
        else
        {
            // Null value

            // TODO Check if this is a mapped column
            if (bDeleteNulls && pProp->cRngBound == 0)
            {
                sqlite3_stmt *pDelProp = pVTab->pDBEnv->pStmts[STMT_DEL_PROP];
                CHECK_CALL(sqlite3_reset(pDelProp));
                sqlite3_bind_int64(pDelProp, 1, lObjectID);
                sqlite3_bind_int64(pDelProp, 2, pProp->iPropID);
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
// TODO Set message?
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
        flexiFindMethod,         /* xFindMethod */
        flexiEavRename,            /* xRename */
        0,                         /* xSavepoint */
        0,                         /* xRelease */
        0                          /* xRollbackTo */
};


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

    // Init module
    CHECK_CALL(sqlite3_create_module_v2(db, "flexi_eav", &flexiEavModule, data, NULL));

    /*
     * Register match_text function, used for searhing on non-FTS indexed columns
     */
    CHECK_CALL(sqlite3_create_function(db, "match_text", 2, SQLITE_UTF8, data,
                                       matchTextFunction, 0, 0));

    result = SQLITE_OK;
    goto FINALLY;

    CATCH:
    flexiEavModuleDestroy(data);
    *pzErrMsg = sqlite3_mprintf(sqlite3_errmsg(db));
    printf("%s", *pzErrMsg);

    FINALLY:
    return result;
}