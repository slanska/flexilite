//
// Created by slanska on 2016-04-08.
//

/*
 * This module implements 'flexi_data' virtual table.
 * This virtual table is eponymous, i.e. it can be used for creating actual virtual tables
 * as well as for CRUD operations on Flexilite classes without corresponding virtual tables.
 *
 * Example of actual virtual table creation:
 * create virtual table if not exists Orders using flexi_data ('{"... class definition JSON ..."}');
 * This will create a new class called 'Orders' as well as corresponding permanent virtual table also called
 * Orders. This table can be accessed as regular SQLite table, with direct access to all
 * rows and columns
 *
 * Example of CRUD operations:
 * select flexi('create class', 'Orders', '{... class definition JSON ...}')
 * -- create new Flexilite class called Orders.
 * No corresponding virtual table will be created by default (unless 4th boolean parameter is passed and equal true)
 * Then this class can be accessed in the following way:
 *
 * insert into flexi_data(ClassName, Data) values ('Orders', '{... data ...}')
 *
 * update flexi_data set Data = '{... data ...}' where ClassName = 'Order' and id = 1;
 * update flexi_data set Data = '{... data ...}' where ClassName = 'Order'
 *  and filter = '{... filter JSON ...}';
 *
 * delete from flexi_data where ClassName = 'Orders' and filter = '{... filter JSON ...}'
 * delete from flexi_data where ClassName = 'Orders' and id = 1
 *
 * select * from flexi_data where ClassName = 'Orders' and filter = '{... filter JSON ...}'
 *
 */

#include "../project_defs.h"

SQLITE_EXTENSION_INIT3

#include "../misc/regexp.h"
#include "flexi_class.h"

/*
 * Forward declarations
 */
extern sqlite3_module _classDefProxyModule;
extern sqlite3_module _adhocQryProxyModule;

struct AdHocQryParams_t
{
    char *zFilter; // JSON string
    char *zOrderBy;
    intptr_t limit;
    sqlite3_int64 ID;
    intptr_t skip;
    char *zBookmark;

    /*
     * User info. If set, will temporarily replace context user info
     */
    char *zUser;
    int fetchDepth;

};

static void AdHoxQryParams_free(struct AdHocQryParams_t *self)
{
    if (self != NULL)
    {
        sqlite3_free(self->zBookmark);
        sqlite3_free(self->zFilter);
        sqlite3_free(self->zOrderBy);
        sqlite3_free(self);
    }
}

/*
 * Proxy virtual table module for flexi_data
 */
struct FlexiDataProxyVTab_t
{
    /*
    * Should be first field. Used for virtual table initialization
    */
    sqlite3_vtab base;

    /*
     * Real implementation
     */
    sqlite3_module *pApi;

    struct flexi_Context_t *pCtx;

    /*
     * Class is defined by its ID. When class definition object is needed, pCtx is used to get it by ID
     * Applicable to both AdHoc and virtual table
     */
    sqlite3_int64 lClassID;

    /*
     * These fields are applicable to ad-hoc
     */
    struct AdHocQryParams_t *pQry;
};

typedef struct FlexiDataProxyVTab_t FlexiDataProxyVTab_t;

static void FlexiDataProxyVTab_free(struct FlexiDataProxyVTab_t *self)
{
    if (self != NULL)
    {
        AdHoxQryParams_free(self->pQry);
        sqlite3_free(self);
    }
}

/*
 * Initialized range bound computed column based on base range property and bound
 * @pRngProp - pointer to base range property
 * @iBound - bound shift, 1 for low bound, 2 - for high bound
 */
static void init_range_column(struct flexi_PropDef_t *pRngProp, unsigned char cBound)
{
    assert(cBound == 1 || cBound == 2);
    struct flexi_PropDef_t *pBound = pRngProp + cBound;

    // We do not need all attributes from original property. Just key ones
    pBound->cRngBound = cBound;
    pBound->iPropID = pRngProp->iPropID;
    pBound->type = pRngProp->type;
    pBound->name.name = sqlite3_mprintf("%s_%d", pRngProp->name.name, cBound - 1);

    // Rest of attributes can be retrieved from base range property by using cRngBound as shift
}

/*
 * Creates new class in transaction
 */
static int _createNewClass(struct flexi_Context_t *pCtx, const char *zClassName, const char *zClassDef,
                           struct flexi_ClassDef_t **ppClassDef)
{
    int result;

    sqlite3_int64 lClassID;

    CHECK_CALL(flexi_ClassDef_create(pCtx, zClassName, zClassDef, 1));
    CHECK_CALL(flexi_Context_getClassIdByName(pCtx, zClassName, &lClassID));
    CHECK_CALL(flexi_ClassDef_load(pCtx, lClassID, ppClassDef));

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;
}

/*
 * Generic method to connect to flexi virtual table.
 * Since eponymous tables in SQLite are implemented with same method for create and connect,
 * the only way to distinguish between CREATE and CONNECT is number and types of passed arguments.
 * This is done by using 2 internal modules, which serve as subclasses via proxy module

 */
static int _createOrConnect(
        sqlite3 *db,

        // Should be instance of flexi_Context_t
        void *pAux,

        /*
         * Number of arguments. Either 3 or 4
         */
        int argc,

        // argv[0] - module name. Expected 'flexi_data'
        // argv[1] - database name ("main", "temp" etc.) Ignored as all changes will be stored in main database
        // argv[2] - either 'flexi_data' or name of new table (class)
        // argv[3] - class definition in JSON (if argv[2] is not 'flexi_data')
        const char *const *argv,

        /*
         * Instance of flexi_ClassDef_t
         */
        sqlite3_vtab **ppVtab,
        char **pzErr
)
{
    assert(argc >= 3);
    int result;

    const char *zClassDef = NULL;

    struct FlexiDataProxyVTab_t *proxyVTab = NULL;

    struct flexi_ClassDef_t *pClassDef = NULL;

    proxyVTab = sqlite3_malloc(sizeof(struct FlexiDataProxyVTab_t));
    CHECK_NULL(proxyVTab);
    memset(proxyVTab, 0, sizeof(struct FlexiDataProxyVTab_t));

    // We expect pAux to be connection context
    proxyVTab->pCtx = pAux;
    proxyVTab->pCtx->nRefCount++;

    CHECK_SQLITE(db, sqlite3_declare_vtab(db, "create table x([select] JSON1 NULL,"
            "[ClassName] TEXT NULL,"
            "[from] TEXT NULL," // Alias to ClassName, for the sake of similarity with SQL syntax
            "[filter] JSON1 NULL," // 'where' clause
            "[orderBy] JSON1 NULL," // 'order by' clause
            "[limit] INTEGER NULL," // 'limit' clause
            "[ID] INTEGER NULL," // object ID (applicable to update and delete)
            "[skip] INTEGER NULL," // 'skip' clause
            "[bookmark] TEXT NULL," // opaque string used for multi-page navigation
            "[user] JSON1 NULL," // user context: either string user ID or JSON with full user info
            "[fetchDepth] INTEGER NULL);" // when to stop when fetching nested/referenced objects
    ));

    /* Check if this is function-type call ('select * from flexi_data()')
    or create-table-type call ('create virtual table T using flexi_data')

     Function-type call will have argv[2] == 'flexi_data' and argc == 3
     Table-create call will have argv[2] == ClassName and argc == 4
     argv[3] will be JSON with class definition
     */
    if (argc == 4)
    {
        const char *zClassName = argv[2];

        // Omitting wrapping single quotes around class def JSON
        zClassDef = String_substr(argv[3], 1, strlen(argv[3]) - 2);

        proxyVTab->pApi = &_classDefProxyModule;

        CHECK_CALL(_createNewClass(proxyVTab->pCtx, zClassName, zClassDef, &pClassDef));
        proxyVTab->lClassID = pClassDef->lClassID;
    } else if (argc == 3 && strcmp(argv[2], "flexi_data") == 0)
    {
        proxyVTab->pApi = &_adhocQryProxyModule;
        proxyVTab->pQry = sqlite3_malloc(sizeof(*proxyVTab->pQry));
        CHECK_NULL(proxyVTab->pQry);
        memset(proxyVTab->pQry, 0, sizeof(*proxyVTab->pQry));

        // TODO ??? pClassDef is null. It will be initialized in xOpen
    } else
    {
        *pzErr = "Invalid arguments. Expected class name and class definition JSON"
                " for virtual table creation or 'flexi_data' for eponymous table";
        result = SQLITE_ERROR;
        goto ONERROR;
    }


    result = SQLITE_OK;
    *ppVtab = (void *) proxyVTab;
    goto EXIT;

    ONERROR:
    if (proxyVTab != NULL)
        FlexiDataProxyVTab_free(proxyVTab);

    EXIT:
    sqlite3_free((void *) zClassDef);
    return result;
}

/*
 *
 */
static int _disconnect(sqlite3_vtab *pVTab)
{
    // TODO
    //    FlexiDataProxyVTab_t *proxyVTab = (void *) pVTab;
    //    int result = proxyVTab->pApi->xDisconnect(pVTab);
    //    FlexiDataProxyVTab_free(proxyVTab);
    //    return result;

    struct FlexiDataProxyVTab_t *proxyVTab = (void *) pVTab;
    int result = proxyVTab->pApi->xDisconnect(pVTab);

    // Check if this was the last connected vtable. If so, free db context
    if (--proxyVTab->pCtx->nRefCount == 0)
    {
        flexi_Context_free(proxyVTab->pCtx);
    }

    FlexiDataProxyVTab_free(proxyVTab);

    return result;
}

/*
 * Finds best existing index for the given criteria, based on index definition for class' properties.
 * There are few search strategies. They fall into one of following groups:
 * I) search by rowid (ObjectID)
 * II) search by indexed properties
 * III) search by rtree ranges
 * IV) full text search (via match function)
 * Due to specifics of internal storage of data (EAV store), these strategies are estimated differently
 * For strategy II every additional search constraint increases estimated cost (since query in this case would be compound from multiple
 * joins)
 * For strategies III and IV it is opposite, every additional constraint reduces estimated cost, since lookup will need
 * to be performed on more restrictive criteria
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
static int _bestIndex(
        sqlite3_vtab *tab,
        sqlite3_index_info *pIdxInfo
)
{
    struct FlexiDataProxyVTab_t *proxyVTab = (void *) tab;
    int result = proxyVTab->pApi->xBestIndex(tab, pIdxInfo);
    return result;
}

/*
 * Starts SELECT on a Flexilite class
 */
static int _open(sqlite3_vtab *pVTab, sqlite3_vtab_cursor **ppCursor)
{
    struct FlexiDataProxyVTab_t *proxyVTab = (void *) pVTab;
    int result = proxyVTab->pApi->xOpen(pVTab, ppCursor);
    return result;
}

/*
 * Delete class and all its object data
 */
static int _destroy(sqlite3_vtab *pVTab)
{
    struct FlexiDataProxyVTab_t *proxyVTab = (void *) pVTab;
    int result = proxyVTab->pApi->xDestroy(pVTab);

    // TODO "delete from [.classes] where NameID = (select NameID from [.names] where Value = :name limit 1);"
    return result;
}

/*
 * Finishes SELECT
 */
static int _close(sqlite3_vtab_cursor *pCursor)
{
    struct FlexiDataProxyVTab_t *proxyVTab = (void *) pCursor->pVtab;
    int result = proxyVTab->pApi->xClose(pCursor);
    return result;
}

static int _filter(sqlite3_vtab_cursor *pCursor, int idxNum, const char *idxStr,
                   int argc, sqlite3_value **argv)
{
    struct FlexiDataProxyVTab_t *proxyVTab = (void *) pCursor->pVtab;
    int result = proxyVTab->pApi->xFilter(pCursor, idxNum, idxStr, argc, argv);
    return result;
}

/*
 * Advances to the next found object
 */
static int _next(sqlite3_vtab_cursor *pCursor)
{
    struct FlexiDataProxyVTab_t *proxyVTab = (void *) pCursor->pVtab;
    int result = proxyVTab->pApi->xNext(pCursor);
    return result;
}

/*
 * Returns 0 if EOF is not reached yet. 1 - if EOF (all rows processed)
 */
static int _eof(sqlite3_vtab_cursor *pCursor)
{
    struct FlexiDataProxyVTab_t *proxyVTab = (void *) pCursor->pVtab;
    int result = proxyVTab->pApi->xEof(pCursor);
    return result;
}

/*
 * Returns value for the column at position iCol (starting from 0).
 * Reads column data from ref-values table, filtered by ObjectID and sorted by PropertyID
 * For the sake of better performance, fetches required columns on demand, sequentially.
 *
 */
static int _column(sqlite3_vtab_cursor *pCursor, sqlite3_context *pContext, int iCol)
{
    struct FlexiDataProxyVTab_t *proxyVTab = (void *) pCursor->pVtab;
    int result = proxyVTab->pApi->xColumn(pCursor, pContext, iCol);
    return result;
}

/*
 * Returns object ID into pRowID
 */
static int _row_id(sqlite3_vtab_cursor *pCursor, sqlite_int64 *pRowid)
{
    struct FlexiDataProxyVTab_t *proxyVTab = (void *) pCursor->pVtab;
    int result = proxyVTab->pApi->xRowid(pCursor, pRowid);
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
static int _update(sqlite3_vtab *pVTab, int argc, sqlite3_value **argv, sqlite_int64 *pRowid)
{
    struct FlexiDataProxyVTab_t *proxyVTab = (void *) pVTab;
    int result = proxyVTab->pApi->xUpdate(pVTab, argc, argv, pRowid);
    return result;
}

/*
 *
 */
static int _find_method(
        sqlite3_vtab *pVtab,
        int nArg,
        const char *zName,
        void (**pxFunc)(sqlite3_context *, int, sqlite3_value **),
        void **ppArg
)
{
    struct FlexiDataProxyVTab_t *proxyVTab = (void *) pVtab;
    int result = proxyVTab->pApi->xFindFunction(pVtab, nArg, zName, pxFunc, ppArg);
    return result;
}

/*
 * Renames class to a new name (zNew)
 * Applicable to VTABLE mode only
 */
static int _rename(sqlite3_vtab *pVtab, const char *zNew)
{
    struct FlexiDataProxyVTab_t *proxyVTab = (void *) pVtab;
    int result = proxyVTab->pApi->xRename(pVtab, zNew);
    return result;
}

/* The methods of the flexi virtual table */
static sqlite3_module flexi_data_module = {
        .iVersion = 0,
        .xCreate = _createOrConnect,
        .xConnect =_createOrConnect,
        .xBestIndex = _bestIndex,
        .xDisconnect = _disconnect,
        .xDestroy = _destroy,
        .xOpen =_open,
        .xClose = _close,
        .xFilter = _filter,
        .xNext = _next,
        .xEof= _eof,
        .xColumn = _column,
        .xRowid = _row_id,
        .xUpdate = _update,
        .xBegin = 0,
        .xSync =0,
        .xCommit = 0,
        .xRollback =0,
        .xFindFunction = _find_method,
        .xRename = _rename,
        .xSavepoint = 0,
        .xRelease = 0,
        .xRollbackTo = 0
};

/*
 * Implementation of MATCH function for non-FTS-indexed columns.
 * For the sake of simplicity function uses in-memory FTS4 table with 1 row, which
 * gets replaced for every call. In future this method should be re-implemented
 * and use more efficient direct calls to Sqlite FTS3/4 API. For now,
 * this looks like a reasonable compromise which should work OK for smaller sets
 * of data.
 */
static void _matchTextFunction(sqlite3_context *context, int argc, sqlite3_value **argv)
{
    // TODO Update lookup statistics
    int result;
    struct flexi_Context_t *pDBEnv = sqlite3_user_data(context);

    assert(pDBEnv);

    if (pDBEnv->pMemDB == NULL)
    {
        CHECK_CALL(sqlite3_open_v2(":memory:", &pDBEnv->pMemDB, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL));

        CHECK_SQLITE(pDBEnv->pMemDB, sqlite3_exec(pDBEnv->pMemDB, "PRAGMA journal_mode = OFF;"
                                                          "create virtual table if not exists [.match_func] using 'fts4' (txt, tokenize=unicode61);", NULL,
                                                  NULL,
                                                  NULL));

        CHECK_STMT_PREPARE(pDBEnv->pMemDB, "insert or replace into [.match_func] (docid, txt) values (1, :1);",
                           &pDBEnv->pMatchFuncInsStmt);

        CHECK_STMT_PREPARE(pDBEnv->pMemDB, "select docid from [.match_func] where txt match :1;",
                           &pDBEnv->pMatchFuncSelStmt);

    }

    sqlite3_reset(pDBEnv->pMatchFuncInsStmt);

    sqlite3_bind_value(pDBEnv->pMatchFuncInsStmt, 1, argv[1]);
    CHECK_STMT_STEP(pDBEnv->pMatchFuncInsStmt, pDBEnv->pMemDB);

    sqlite3_reset(pDBEnv->pMatchFuncSelStmt);
    sqlite3_bind_value(pDBEnv->pMatchFuncSelStmt, 1, argv[0]);
    CHECK_STMT_STEP(pDBEnv->pMatchFuncSelStmt, pDBEnv->pMemDB);
    sqlite3_int64 lDocID = sqlite3_column_int64(pDBEnv->pMatchFuncSelStmt, 0);
    if (lDocID == 1)
        sqlite3_result_int(context, 1);
    else
        sqlite3_result_int(context, 0);

    goto EXIT;

    ONERROR:
    sqlite3_result_error_code(context, result);
    EXIT:
    {}
}

/*
 * Registers 'flexi_data' function and virtual table module
 */
int flexi_data_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi,
        struct flexi_Context_t *pCtx
)
{
    (void) pApi;

    int result;

    // Init module
    CHECK_CALL(sqlite3_create_module_v2(db, "flexi_data", &flexi_data_module, pCtx, NULL));
//    CHECK_CALL(sqlite3_create_module_v2(db, "flexi_data", &flexi_data_module, pCtx, (void *) flexi_Context_free));

    /*
     * TODO move to general functions
     * Register match_text function, used for searching on non-FTS indexed columns
     */
    CHECK_CALL(sqlite3_create_function_v2(db, "match_text", 2, SQLITE_UTF8, pCtx,
                                          _matchTextFunction, 0, 0, NULL));

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:
    *pzErrMsg = sqlite3_mprintf(sqlite3_errmsg(db));
    printf("%s", *pzErrMsg);

    EXIT:
    return result;
}
