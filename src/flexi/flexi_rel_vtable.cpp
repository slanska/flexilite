//
// Created by slanska on 2018-10-16.
//

/*
 * This is implementation of SQLite virtual table module - flexirel,
 * which allows normal SQL access to referenced data, via .ref-values table
 * flexirel tables are normally created during converting schema from
 * existing SQLite database to Flexilite format.
 *
 * Virtual table can be created using the following:
 *
 * create virtual table EmployeeTerritories using flexirel
 * (EmployeeID, TerritoryID, Employee hidden, Territories hidden);
 *
 * flexirel virtual table establishes map to [.ref-values] table so that
 * all CRUD operations are executed on that table.
 * Exactly 4 columns must be specified. First 2 columns correspond to ObjectID and Value fields in
 * [.ref-values] table. Third and fourth columns define specific class and property names
 *
 * 'flexirel' tables get re-created automatically every time when class or property get renamed.
 * If class or property are removed, or property type changed to non-reference type, corresponding table
 * gets deleted.
 *
 * flexirel tables are used mostly internally for importing data from existing non-Flexilite databases.
 * When importing data from inline JSON or external JSON file, Flexilite first checks if there is a class
 * with required name. If no class is found, Flexilite checks existing flexirel tables which map to
 * corresponding class and property.
 *
 * flexirel operates on enum representatio of object IDs, thus emulating
 * many-to-many relation in a regular RDBMS. So, while internally .ref-values
 * stores real object IDs, flexirel exposes their "udid" special properties.
 *
 * Due to its nature, it is allowed to create many flexirel tables on the same reference property,
 * as these tables essentially serve as views, so there is negligible overhead related to the flexirel
 * table maintenance. Note that class and reference property must exist before call to create flexirel
 * virtual table.
 *
 * Implementation details:
 *
 * flexirel vtable uses reference to shared DBContext to pass calls to Lua code.
 * This reference is available in FlexiliteContext_t struct
 *
 * flexirel vtable is mapped to the .ref-values table with given PropertyID. ObjectID is treated as `fromID`
 * Value - as `toID`. These columns are declared as hidden, i.e. there are not returned by select * from <flexirel_table>
 * Instead, user is presented with user defined IDs which correspond to original row IDs in the source non-Flexilite
 * database. For example, in Northwind.EmployeeTerritories has EmployeeID - this will be exposed as user defined `fromID`.
 * TerritoryID will be servind as user defined `toID`. Two other columns will be also declared - EmployeeID_x and TerritoryID_x,
 * which will map to ObjectID and Value columns of .ref-values, respectively.
 *
 *
 *
 */

#include <vector>
#include <string>

#ifdef __cplusplus
extern "C" {
#endif

#include "../project_defs.h"
#include "flexi_data.h"

SQLITE_EXTENSION_INIT3

using namespace std;

struct FlexiRel_vtab : sqlite3_vtab
{
public:
    string _className;
    string _propName;
    int64_t _classID = 0;
    int64_t _propID = 0;
    string _col1;
    string _col2;
    FlexiliteContext_t *pCtx;
};

struct FlexiRel_vtab_cursor : sqlite3_vtab_cursor
{

    inline FlexiRel_vtab &getVTab() const
    {
        auto result = (FlexiRel_vtab *) this->pVtab;
        return *result;
    }
};

static string &_extractColumnName(string &ss)
{
    ss.substr();
    return ss;
}

/*
 * Prepares Lua stack for flexrel call of Lua function
 */
static void prepare_call(FlexiliteContext_t *pCtx, const char *szFuncName)
{
    lua_rawgeti(pCtx->L, LUA_REGISTRYINDEX, pCtx->DBContext_Index);
    lua_getfield(pCtx->L, -1, "flexirel");
    lua_getfield(pCtx->L, -1, szFuncName);
}

/*
 * argc must be exactly 7:
 * 0 - "flexirel"
 * 1 - "main" or "temp" or ...
 * 2 - new table name
 * 3 - column mapped to ObjectID
 * 4 - column mapped to Value
 * 5 - class name
 * 6 - reference property name
 */
static int _create_connect(sqlite3 *db, void *pAux,
                           int argc, const char *const *argv,
                           sqlite3_vtab **ppVTab,
                           char **pzErr)
{
    int result = SQLITE_OK;
    const char *zCreateTable = nullptr;

    if (argc != 7)
    {
        *pzErr = sqlite3_mprintf(
                "Flexirel expects 4 column names: column_name_1, column_name_2, class_name, property_name");
        return SQLITE_ERROR;
    }

    string sTable(argv[2]);
    string sDB(argv[1]);

    // Initialize
    auto vtab = new FlexiRel_vtab();
    vtab->_className = string(argv[3]);
    vtab->_propName = string(argv[4]);
    vtab->_col1 = string(argv[5]);
    vtab->_col2 = string(argv[6]);
    vtab->pCtx = static_cast<FlexiliteContext_t *>(pAux);

    *ppVTab = vtab;

    lua_checkstack(vtab->pCtx->L, 10);

    int oldTop = lua_gettop(vtab->pCtx->L);

    // Call Lua implementation
    prepare_call(vtab->pCtx, "create_connect");
    // DBContext
    lua_rawgeti(vtab->pCtx->L, LUA_REGISTRYINDEX, vtab->pCtx->DBContext_Index);
    // dbName
    lua_pushstring(vtab->pCtx->L, argv[1]);
    // tableName
    lua_pushstring(vtab->pCtx->L, argv[2]);
    // className
    lua_pushstring(vtab->pCtx->L, argv[5]);
    // propName
    lua_pushstring(vtab->pCtx->L, argv[6]);
    // colName
    lua_pushstring(vtab->pCtx->L, argv[3]);
    // colName2
    lua_pushstring(vtab->pCtx->L, argv[4]);

    // 7 arguments, 2 results, no error handler
    if (lua_pcall(vtab->pCtx->L, 7, 2, NULL))
    {
        *pzErr = sqlite3_mprintf("Flexilite DBContext(db): %s\n", lua_tostring(vtab->pCtx->L, -1));
        result = SQLITE_ERROR;
        goto ONERROR;
    }

    vtab->_propID = lua_tointeger(vtab->pCtx->L, -2);
    zCreateTable = lua_tostring(vtab->pCtx->L, -1);

    result = sqlite3_declare_vtab(db, zCreateTable);
    if (result != SQLITE_OK)
    { goto ONERROR; }

    goto EXIT;

    ONERROR:
    delete vtab;
    EXIT:
    // Restore Lua stack
    lua_settop(vtab->pCtx->L, oldTop);
    return result;
}

/*
 * TODO Needed?
 */
static int _best_index(
        sqlite3_vtab *tab,
        sqlite3_index_info *pIdxInfo
)
{
    auto vtab = static_cast<FlexiRel_vtab *>(tab);

    // Call Lua implementation

    return SQLITE_OK;
}

static int _disconnect_destroy(sqlite3_vtab *pVTab)
{
    auto vtab = static_cast<FlexiRel_vtab *>(pVTab);
    delete vtab;
    return SQLITE_OK;
}

/*
 * Starts SELECT on a Flexilite class
 */
static int _open(sqlite3_vtab *pVTab, sqlite3_vtab_cursor **ppCursor)
{
    auto cur = new FlexiRel_vtab_cursor();
    cur->pVtab = pVTab;
    *ppCursor = cur;
    int result = SQLITE_OK;
    return result;
}

/*
 * Finishes SELECT
 */
static int _close(sqlite3_vtab_cursor *pCursor)
{
    //    struct flexi_VTabCursor *cur = (flexi_VTabCursor *) (void *) pCursor;
    //    return flexi_VTabCursor_free(cur);
    return SQLITE_OK;
}

static int _filter(sqlite3_vtab_cursor *pCursor, int idxNum, const char *idxStr,
                   int argc, sqlite3_value **argv)
{
    // Call Lua implementation
    return SQLITE_OK;
}

/*
 * Advances to the next found object
 */
static int _next(sqlite3_vtab_cursor *pCursor)
{
    int result = SQLITE_OK;
    return result;
}

/*
 * Returns 0 if EOF is not reached yet. 1 - if EOF (all rows processed)
 */
static int _eof(sqlite3_vtab_cursor *pCursor)
{
    struct flexi_VTabCursor *cur = (flexi_VTabCursor *) (void *) pCursor;
    return cur->iEof > 0;
}

/*
 * Returns value for the column at position iCol (starting from 0).
 * Reads column data from ref-values table, filtered by ObjectID and sorted by PropertyID
 * For the sake of better performance, fetches required columns on demand, sequentially.
 *
 */
static int _column(sqlite3_vtab_cursor *pCursor, sqlite3_context *pContext, int iCol)
{
    int result = SQLITE_OK;
    return result;
}

/*
 * Returns PropIndex into pRowID
 */
static int _row_id(sqlite3_vtab_cursor *pCursor, sqlite_int64 *pRowid)
{
    auto *cur = (struct flexi_VTabCursor *) (void *) pCursor;
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
static int _update(sqlite3_vtab *pVTab, int argc, sqlite3_value **argv, sqlite_int64 *pRowid)
{
    // Call Lua implementation
    int result = SQLITE_OK;

    FlexiRel_vtab *vtab = (FlexiRel_vtab *) pVTab;

    // Call Lua implementation
    prepare_call(vtab->pCtx, "update");

    // DBContext
    lua_rawgeti(vtab->pCtx->L, LUA_REGISTRYINDEX, vtab->pCtx->DBContext_Index);
    // propID
    lua_pushinteger(vtab->pCtx->L, vtab->_propID);
    // newRowID
//    lua_pushstring(vtab->pCtx->L, argv[2]);
    // oldRowID
//    lua_pushstring(vtab->pCtx->L, argv[0]);
    // fromID
//    lua_pushstring(vtab->pCtx->L, argv[6]);
    // toID
//    lua_pushstring(vtab->pCtx->L, argv[3]);
    // fromUDID
//    lua_pushstring(vtab->pCtx->L, argv[4]);
    // toUDID
//    lua_pushstring(vtab->pCtx->L, argv[4]);

    // 7 arguments, 2 results, no error handler
    if (lua_pcall(vtab->pCtx->L, 8, 0, NULL))
    {
        vtab->zErrMsg = sqlite3_mprintf("Flexilite DBContext(db): %s\n", lua_tostring(vtab->pCtx->L, -1));
        result = SQLITE_ERROR;
        goto ONERROR;
    }


    if (result != SQLITE_OK)
    { goto ONERROR; }

    goto EXIT;

    ONERROR:

    EXIT:

    return result;
}

static int _find_method(
        sqlite3_vtab *pVtab,
        int nArg,
        const char *zName,
        void (**pxFunc)(sqlite3_context *, int, sqlite3_value **),
        void **ppArg
)
{
    int result = SQLITE_OK;
    return result;
}

/*
 * Renames class to a new name (zNew)
 * TODO use flexi_class_rename
 */
static int _rename(sqlite3_vtab *pVtab, const char *zNew)
{
    // drop table

    // re-create virtual table with new name

    return SQLITE_OK;
}

static sqlite3_module _flexirel_vtable_module = {
        .iVersion = 0,
        .xCreate = _create_connect,
        .xConnect = _create_connect,
        .xBestIndex = _best_index,
        .xDisconnect = _disconnect_destroy,
        .xDestroy = _disconnect_destroy,
        .xOpen = _open,
        .xClose = _close,
        .xFilter = _filter,
        .xNext = _next,
        .xEof = _eof,
        .xColumn = _column,
        .xRowid = _row_id,
        .xUpdate = _update,
        .xBegin = nullptr,
        .xSync = nullptr,
        .xCommit= nullptr,
        .xRollback = nullptr,
        .xFindFunction = _find_method,
        .xRename = _rename,
        .xSavepoint = nullptr,
        .xRelease = nullptr
};

int register_flexi_rel_vtable(sqlite3 *db, FlexiliteContext_t *pCtx)
{
    // TODO pass
    int result = sqlite3_create_module(db, "flexi_rel", &_flexirel_vtable_module, pCtx);
    return result;
}

#ifdef __cplusplus
}
#endif
