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
 * [.ref-values] table. Third and fourth columns are used to narrow scope to specific class and property
 * If either 3rd or 4th columns or both are text, they must be valid class and reference property
 * names.
 *
 * 'flexirel' tables get re-created automatically every time when class or property get renamed.
 * If class or property are removed, or property type changed to non-reference type, corresponding table
 * gets deleted.
 *
 * flexirel tables are mostly used for importing data from existing non-Flexilite databases.
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
 * argc must be exactly 7:
 * 0 - "flexirel"
 * 1 - "main" or "temp" or ...
 * 2 - new table name
 * 3 - class name
 * 4 - reference property name
 * 5 - column mapped to ObjectID
 * 6 - column mapped to Value
 */
static int _create_connect(sqlite3 *db, void *pAux,
                           int argc, const char *const *argv,
                           sqlite3_vtab **ppVTab,
                           char **pzErr)
{
    if (argc != 7)
    {
        // TODO
        *pzErr = sqlite3_mprintf(
                "Flexirel expects 4 column names: class_name, property_name, column_name_1, column_name_2");
        return SQLITE_ERROR;
    }

    string sTable(argv[2]);
    string sDB(argv[1]);

    // Find class and property IDs

    // Check if property is a reference property

    // Parse column names

    // Initialize
    auto vtab = new FlexiRel_vtab();
    vtab->_className = string(argv[3]);
    vtab->_propName = string(argv[4]);
    vtab->_col1 = string(argv[5]);
    vtab->_col2 = string(argv[6]);

    *ppVTab = vtab;

    auto zCreateTable = sqlite3_mprintf("create table [%s] (PropID int, Col1, Col2, ID int, ctlv int, ExtData json1);");
    int result = sqlite3_declare_vtab(db, zCreateTable);
    sqlite3_free(zCreateTable);
    if (result != SQLITE_OK)
    { goto ERROR; }

    ERROR:
    delete vtab;
    EXIT:
    return SQLITE_OK;
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
    struct flexi_VTabCursor *cur = (flexi_VTabCursor *) (void *) pCursor;
    return flexi_VTabCursor_free(cur);
}

static int _filter(sqlite3_vtab_cursor *pCursor, int idxNum, const char *idxStr,
                   int argc, sqlite3_value **argv)
{
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
    int result = SQLITE_OK;
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


#ifdef __cplusplus
}
#endif