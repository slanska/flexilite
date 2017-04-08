//
// Created by slanska on 2017-04-08.
//

#include "../project_defs.h"

SQLITE_EXTENSION_INIT3

#include "../misc/regexp.h"
#include "flexi_class.h"

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
    return 0;
}

static int _disconnect(sqlite3_vtab *pVTab)
{
    return SQLITE_OK;
}

/*
 * Starts SELECT on a Flexilite class
 */
static int _open(sqlite3_vtab *pVTab, sqlite3_vtab_cursor **ppCursor)
{}

/*
 * Delete class and all its object data
 */
static int _destroy(sqlite3_vtab *pVTab)
{
    //pVTab->pModule

    // TODO "delete from [.classes] where NameID = (select NameID from [.names] where Value = :name limit 1);"
    return SQLITE_OK;
}

/*
 * Finishes SELECT
 */
static int _close(sqlite3_vtab_cursor *pCursor)
{
    return 0;
}

static int _filter(sqlite3_vtab_cursor *pCursor, int idxNum, const char *idxStr,
                   int argc, sqlite3_value **argv)
{
    return 0;
}

/*
 * Advances to the next found object
 */
static int _next(sqlite3_vtab_cursor *pCursor)
{
    return 0;
}

/*
 * Returns 0 if EOF is not reached yet. 1 - if EOF (all rows processed)
 */
static int _eof(sqlite3_vtab_cursor *pCursor)
{
    return 0;
}

/*
 * Returns value for the column at position iCol (starting from 0).
 * Reads column data from ref-values table, filtered by ObjectID and sorted by PropertyID
 * For the sake of better performance, fetches required columns on demand, sequentially.
 *
 */
static int _column(sqlite3_vtab_cursor *pCursor, sqlite3_context *pContext, int iCol)
{
    return 0;
}

/*
 * Returns object ID into pRowID
 */
static int _row_id(sqlite3_vtab_cursor *pCursor, sqlite_int64 *pRowid)
{
    return 0;
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
    return 0;
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
    return 0;
}

/*
 * Renames class to a new name (zNew)
 * TODO use flexi_class_rename
 */
static int _rename(sqlite3_vtab *pVtab, const char *zNew)
{
    return 0;
}

/*
 * Eponymous table proxy module.
 * Used when flexi_data is accessed directly, not via virtual table
 */
static sqlite3_module _adhocQryProxyModule = {
        .iVersion = 0,
        .xCreate = NULL,
        .xConnect = NULL,
        .xBestIndex = _bestIndex,
        .xDisconnect = _disconnect,
        .xDestroy = _destroy,
        .xOpen = _open,
        .xClose = _close,
        .xFilter = _filter,
        .xNext = _next,
        .xEof = _eof,
        .xColumn = _column,
        .xRowid = _row_id,
        .xUpdate = _update,
        .xBegin = NULL,
        .xSync = NULL,
        .xCommit= NULL,
        .xRollback = NULL,
        .xFindFunction = _find_method,
        .xRename = _rename,
        .xSavepoint = NULL,
        .xRelease = NULL,
        .xRollback = NULL
};

