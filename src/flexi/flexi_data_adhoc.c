//
// Created by slanska on 2017-04-08.
//

/*
 * flexi_data eponymous virtual table for ad-hoc CRUD operations
 * For SELECT the following columns are applicable:
 * ClassName
 * filter
 * rowid
 * bookmark
 * user
 *
 * For INSERT:
 * ClassName
 * Data
 * rowid
 * user
 *
 * For UPDATE:
 * ClassName
 * Data
 * filter or rowid
 * user
 *
 * For DELETE:
 * ClassName
 * filter or rowid
 * user
 */

#include "../project_defs.h"
#include "flexi_data.h"

SQLITE_EXTENSION_INIT3

#include "../misc/regexp.h"
#include "flexi_class.h"
#include "../util/StringBuilder.h"

/*
 * Any filtering on flexi_data's columns will be passed in aConstraints, by column indexes
 */
static int _bestIndex(
        sqlite3_vtab *tab,
        sqlite3_index_info *pIdxInfo
)
{
    StringBuilder_t sb;
    StringBuilder_init(&sb);

    int argCount = 0;

    if (pIdxInfo->nConstraint > 0)
    {
        for (int cc = 0; cc < pIdxInfo->nConstraint; cc++)
        {
            if (pIdxInfo->aConstraint[cc].usable)
            {
                pIdxInfo->aConstraintUsage[cc].argvIndex = ++argCount;
                int col = pIdxInfo->aConstraint[cc].iColumn;
                // Build WHERE part based on op codes

                switch (col)
                {
                    case FLEXI_DATA_COL_CLASS_NAME:
                        // Filter by class name
                        break;

                    case FLEXI_DATA_COL_ID:
                        // TODO Filter by object ID
                        break;

                    case FLEXI_DATA_COL_BOOKMARK:
                        // TODO Filter by bookmark
                        break;

                    case FLEXI_DATA_COL_USER:
                        // TODO Filter by user
                        break;

                    case FLEXI_DATA_COL_FILTER:
                        // TODO
                        break;

                    default:
                        //                    pIdxInfo->
                        // TODO Error
                        break;
                }
            }
        }

        pIdxInfo->estimatedCost = 0; // TODO Needed?
        pIdxInfo->idxNum = 1; // TODO
        pIdxInfo->idxStr = sqlite3_mprintf("%s", sb.zBuf);
        pIdxInfo->needToFreeIdxStr = true;
    }

    StringBuilder_clear(&sb);
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
{
    // TODO
    *ppCursor = sqlite3_malloc(sizeof(struct flexi_VTabCursor));
    if (*ppCursor == NULL)
        return SQLITE_NOMEM;

    memset(*ppCursor, 0, sizeof(struct flexi_VTabCursor));
    struct flexi_VTabCursor *cur = (void *) *ppCursor;
    cur->iEof = -1;
    cur->lObjectID = -1;

    return SQLITE_OK;
}

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

    // TODO Dispose cursor

    struct flexi_VTabCursor *cur = (void *) pCursor;

    flexi_VTabCursor_free(cur);
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
    // TODO
    return 1;
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
 * Inserts or updates objects
 * pDataSource is result of select from json_tree and is expected to be positioned on the first row with given parent
 */
static int
_processObjectUpsert(struct FlexiDataProxyVTab_t *dataVTab, sqlite3_int64 lClassID, sqlite3_int64 lObjectID,
                     bool insert, sqlite3_stmt *pDataSource, int parent)
{
    return 0;
}

/*
 * Inserts or updates array of atoms/objects
 * pDataSource is result of select from json_tree and is expected to be positioned on the first row with given parent
 */
static int
_processPropertyArrayUpsert(struct FlexiDataProxyVTab_t *dataVTab, sqlite3_int64 lClassID,
                            struct flexi_PropDef_t *propDef,
                            bool insert, sqlite3_stmt *pDataSource, int parent)
{
    return 0;
}

/*
 * Inserts or update data into single object
 * pDataSource is result of select from json_tree and is expected to be positioned on the current row
 */
static int
_upsertPropData(struct FlexiDataProxyVTab_t *dataVTab,
                sqlite3_stmt *pDataSource, bool insert, int parent,
                sqlite3_int64 lClassID)
{
    int result;
    char *zPropName = NULL;
    flexi_ClassDef_t *pClassDef;

    CHECK_CALL(flexi_ClassDef_load(dataVTab->pCtx, lClassID, &pClassDef));

    int thisParent = sqlite3_column_int(pDataSource, 5);
    if (thisParent != parent)
        goto EXIT;

    sqlite3_free(zPropName);
    getColumnAsText(&zPropName, pDataSource, 0);

    sqlite3_int64 lPropID;
    CHECK_CALL(flexi_Context_getPropIdByClassIdAndName(dataVTab->pCtx, lClassID, zPropName, &lPropID));
    bool bAtom = sqlite3_column_int(pDataSource, 0) == 0;
    const char *zType = (const char *) sqlite3_column_text(pDataSource, 2);

    if (lPropID == -1)
        // Property not found
    {
        if (!pClassDef->bAllowAnyProps)
        {
            flexi_Context_setError(dataVTab->pCtx, SQLITE_ERROR,
                                   sqlite3_mprintf("Property %s is not defined in class %s", zPropName,
                                                   pClassDef->name.name));
            result = SQLITE_ERROR;
            goto ONERROR;
        }

        // Use name instead
        /*
         * if atom - save individual value
         * else process as object or array
         */

    }
    else
        // Property found. Validate and process
    {
        struct flexi_PropDef_t *prop;
        flexi_ClassDef_getPropDefById(pClassDef, lPropID, &prop);

        // Check if this is an atomic value
        if (bAtom)
        {
            sqlite3_value *vv = sqlite3_column_value(pDataSource, 1);
            CHECK_CALL(flexi_PropDef_validateValue(prop, pClassDef, vv));

            // If property is not mapped to fixed column, save it in [.ref-values]

            // otherwise, assign to object save
        }
        else
            // Possibly, nested object or array of values or nested objects
        {
            if (strcmp(zType, "array") == 0)
            {

            }
            else
                if (strcmp(zType, "object") == 0)
                {

                }
                else
                {
                    // TODO Invalid element type
                }
        }

    }

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    sqlite3_free(zPropName);
    return result;
}

static int
_processDataUpsert(struct FlexiDataProxyVTab_t *dataVTab,
                   sqlite3_int64 lClassID,
                   sqlite3_stmt *pDataSource, bool insert)
{
    int result;
    int parent = sqlite3_column_int(pDataSource, 5);
    bool bAtom = sqlite3_column_int(pDataSource, 0) == 0;
    if (bAtom)
    {

    }
    else
    {
        const char *zType = (const char *) sqlite3_column_text(pDataSource, 2);
        if (strcmp(zType, "array") == 0)
        {
            //_processPropertyArrayUpsert(dataVTab, lClassID, )
        }
        else
            if (strcmp(zType, "object") == 0)
            {

            }
            else
            {
                result = SQLITE_ERROR;
                flexi_Context_setError(dataVTab->pCtx, result, sqlite3_mprintf("Invalid token type %s", zType));
                goto ONERROR;
            }
    }

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
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
The row with rowid argv[0] is updated with rowid argv[1] and new values in argv[2+] parameters.
 This will occur when an SQL statement updates a rowid, as in the statement:

UPDATE table SET rowid=rowid+1 WHERE ...;

 Layout of argv (+2):
    FLEXI_DATA_COL_SELECT = 0,
    FLEXI_DATA_COL_CLASS_NAME = 1,
    FLEXI_DATA_COL_FILTER = 2,
    FLEXI_DATA_COL_ORDER_BY = 3,
    FLEXI_DATA_COL_LIMIT = 4,
    FLEXI_DATA_COL_ID = 5,
    FLEXI_DATA_COL_SKIP = 6,
    FLEXI_DATA_COL_DATA = 7,
    FLEXI_DATA_COL_BOOKMARK = 8,
    FLEXI_DATA_COL_USER = 9,
    FLEXI_DATA_COL_FETCH_DEPTH = 10

 Iterate through all elements in data JSON
 1) atom - property or name
 2) array - of atoms, objects or references
 3) object (nested or referenced)

 TODO
 first item will have parent null. It can be array or object (of given class)
 if parent = thisID - process child element
 else if parent != thisParent - processing is done

 */
static int _update(sqlite3_vtab *pVTab, int argc, sqlite3_value **argv, sqlite_int64 *pRowid)
{
    int result;

    sqlite3_stmt *pDataSource = NULL; // Parsed JSON data

    struct FlexiDataProxyVTab_t *dataVTab = (void *) pVTab;

    char *zClassName = (char *) sqlite3_value_text(argv[FLEXI_DATA_COL_CLASS_NAME + 2]);
    if (!zClassName || strlen(zClassName) == 0)
    {
        result = SQLITE_NOTFOUND;
        flexi_Context_setError(dataVTab->pCtx, result, sqlite3_mprintf("Class name is expected"));
        goto ONERROR;
    }

    flexi_ClassDef_t *pClassDef;
    CHECK_CALL(flexi_ClassDef_loadByName(dataVTab->pCtx, zClassName, &pClassDef));

    if (argc == 1)
        // Delete
    {}
    else
    {
        // Data will be in argv[9]
        // Class name will be in argv[3]
        bool insert = argv[0] == NULL;

        sqlite3_int64 lObjectID = sqlite3_value_int64(argv[1]);

        /*
        * Parse data JSON
        */
        CHECK_STMT_PREPARE(dataVTab->pCtx->db,
                           "select "
                                   "key, " // 0
                                   "value, " // 1
                                   "type, " // 2
                                   "atom, " // 3
                                   "id, " // 4
                                   "parent, " // 5
                                   "fullkey, " // 6
                                   "path " // 7
                                   "from json_tree(:1);", &pDataSource);
        CHECK_CALL(sqlite3_bind_text(pDataSource, 1,
                                     (const char *) sqlite3_value_text(argv[FLEXI_DATA_COL_DATA + 2]), -1,
                                     NULL));
        result = sqlite3_step(pDataSource);
        if (result == SQLITE_ROW)
        {
            CHECK_CALL(_processDataUpsert(dataVTab, pClassDef->lClassID, pDataSource, insert));
        }
        else
            if (result != SQLITE_DONE)
                goto ONERROR;


    }

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    sqlite3_finalize(pDataSource);
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
 * Eponymous table module.
 * Used when flexi_data is accessed directly (select * from flexi_data), not via virtual table
 */
sqlite3_module _adhocQryProxyModule = {
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
        .xRelease = NULL
};

