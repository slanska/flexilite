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
#include "flexi_class.h"
#include "../util/StringBuilder.h"
#include "flexi_Object.h"
#include "../util/json_proc.h"

SQLITE_EXTENSION_INIT3

/*
 * Special property names (starting from '$')
 */
#define FLEXI_PROP_ID           "$id"
#define FLEXI_PROP_CLASS        "$class"
#define FLEXI_PROP_REF_ID       "$ref-id"
#define FLEXI_PROP_REF_NAME       "$ref-name"
#define FLEXI_PROP_REF_CODE       "$ref-code"
#define FLEXI_PROP_CODE       "$code"
#define FLEXI_PROP_NAME       "$name"
#define FLEXI_PROP_VERSION       "$version"

/*
 * Column numbers for result of json_tree call
 */
enum UPSERT_JSON_COLUMNS
{
    JSON_TREE_KEY = 0,
    JSON_TREE_VALUE = 1,
    JSON_TREE_TYPE = 2,
    JSON_TREE_ATOM = 3,
    JSON_TREE_ID = 4,
    JSON_TREE_PARENT = 5,
    JSON_TREE_FULLKEY = 6,
    JSON_TREE_PATH = 7
};

typedef struct _UpsertParams_t
{
    /*
     * virtual table for adhoc processing
     */
    FlexiDataProxyVTab_t *dataVTab;

    /*
     * If class name was passed in ClassName, its ID will be passed here
     * Otherwise, it would be 0.
     * If set, this value will have priority over $className property in JSON payload
     * (if $className is passed, it should match lExpectedClassID)
     */
    sqlite3_int64 lExpectedClassID;

    /*
    * Similarly to lExpectedClassID - value is passed in ID column or 0.
     * Takes priority over $id special property passed in JSON payload
     * (if $id is passed, it should match lExpectedObjectID)
    */
    sqlite3_int64 lExpectedObjectID;

    /*
     * true if this is insert operation
     */
    bool insert;

    /*
     * Cursor to get JSON values
     */
    sqlite3_stmt *pDataSource;

    /*
     * Scope of parent ID
     */
    int parent;

    /*
     * Recursion level when processing nested objects
     * When 0, it is top level object (or item in array)
     * Save operations run after full completion of item of level 0 (all nested objects/props/array
     * should be loaded, validated and pre-processed already)
     */
    int level;
} _UpsertParams_t;

/*
 * Internal structure to build data column content
 */
typedef struct _GetDataParams_t
{
    StringBuilder_t sb;
    flexi_VTabCursor *cur;
    enum FLEXI_DATA_LOAD_ROW_MODES eLoadRowMode;
} _GetDataParams_t;

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

static int
_buildDataColumn(_GetDataParams_t *p)
{
    int result;

    // Assume array of items. Depending on actual number of items and load mode, starting position may change
    StringBuilder_appendRaw(&p->sb, "[", 1);


    result = SQLITE_OK;

    return result;
}

/*
 * Returns value for the column at position iCol (starting from 0).
 * For 'Data' builds JSON
 *
 */
static int _column(sqlite3_vtab_cursor *pCursor, sqlite3_context *pContext, int iCol)
{
    int result;

    _GetDataParams_t p = {};

    p.cur = (flexi_VTabCursor *) pCursor;

    switch (iCol)
    {
        case FLEXI_DATA_COL_DATA:
            StringBuilder_init(&p.sb);
            CHECK_CALL(_buildDataColumn(&p));


            break;

        case FLEXI_DATA_COL_ID:
            break;

        case FLEXI_DATA_COL_CLASS_NAME:
            break;

        default:
            // TODO Fail if invalid column was specified
            sqlite3_result_null(pContext);
            break;
    }

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:


    EXIT:

    return result;
}

/*
 * Returns object ID into pRowID
 */
static int _row_id(sqlite3_vtab_cursor *pCursor, sqlite_int64 *pRowid)
{
    return 0;
}

/*
 * Following set of _upsert* methods are to handle update/insert operations for different types of data
 * They have similar set of arguments and all follow the same pattern of navigation over JSON tokens in json_tree output.
 * They expect first item already positioned and when exiting, they leave position immediately after last processed item (if more items exist),
 * thus allowing next handler to start from established position
 *
 * These functions are:
 * _upsertObject - to process individual object
 * _upsertObjectArray - to process array of objects
 * _upsertProperty - to process single property value (whi
 *
 * =================
 * _upsertOrDelete (entry point):
 *
 * if array -> next, _upsertObjectArray
 * else if object -> _upsertObject
 * else error
 *
 * =================
 * _upsertObjectArray:
 * get id
 * loop next, get type - if object -> _upsertObject
 * else error
 *
 * =================
 * _upsertObject:
 * get id
 * detect/get class id and class def
 * check access rules for current user
 * loop next, if registered property -> get prop def, prop ID
 * else if allowAny == false -> error
 * get name, name ID
 *
 * check prop type
 * if atom - _processAtomProp
 * if array - _processArrayProp
 * if object - _processObjectProp
 *
 * get $id, get $class
 * if !insert -> load existing object (skip new properties)
 * validate object
 * save object
 *
 * =================
 * _processArrayProp:
 * next
 * loop next,
 * if atom -> _processAtomProp
 * else if object -> _processObjectProp
 * else error
 *
 * =================
 * _processAtomProp:
 * check if value type is valid
 * check access rules for current user
 * add prop to object prop map
 *
 * =================
 * _processObjectProp:
 * check, guess class ID
 * get class def
 * _upsertObject
 *
 * =================
 * _detectClass
 * $class
 * pp->lExpectedClassID
 * if parentProp && it is ref -> determine class based on static/dynamic rules
 */

static int
_upsertObject(_UpsertParams_t *pp, sqlite3_int64 lExpectedObjectID);

/*
 *
 */
static int
_loadObjPropsFromJSON(_UpsertParams_t *p)
{
    int result;

    //

    result = SQLITE_OK;

    return result;
}

/*
 * Inserts or updates array of atoms/objects
 * pDataSource is result of select from json_tree and is expected to be positioned on the first row with given parent
 */
static int
_upsertPropertyArray(FlexiDataProxyVTab_t *dataVTab, sqlite3_int64 lClassID,
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
_upsertProperty(_UpsertParams_t *pp)
{
    int result;
    char *zPropName = NULL;
    flexi_ClassDef_t *pClassDef;

    CHECK_CALL(flexi_ClassDef_load(pp->dataVTab->pCtx, pp->lExpectedClassID, &pClassDef));

    int thisParent = sqlite3_column_int(pp->pDataSource, JSON_TREE_PARENT);
    if (thisParent != pp->parent)
        goto EXIT;

    sqlite3_free(zPropName);
    getColumnAsText(&zPropName, pp->pDataSource, JSON_TREE_KEY);

    sqlite3_int64 lPropID;
    CHECK_CALL(flexi_Context_getPropIdByClassIdAndName(pp->dataVTab->pCtx, pp->lExpectedClassID, zPropName, &lPropID));
    bool bAtom = sqlite3_column_int(pp->pDataSource, JSON_TREE_ATOM) == 0;
    const char *zType = (const char *) sqlite3_column_text(pp->pDataSource, JSON_TREE_TYPE);

    if (lPropID == -1)
        // Property not found
    {
        if (!pClassDef->bAllowAnyProps)
        {
            flexi_Context_setError(pp->dataVTab->pCtx, SQLITE_ERROR,
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

        if (bAtom)
        {

        }
        else
        {
            if (strcmp(zType, "") == 0)
            {

            }
        }

    }
    else
        // Property found. Validate and process
    {
        struct flexi_PropDef_t *prop;
        flexi_ClassDef_getPropDefById(pClassDef, lPropID, &prop);

        // Check if this is an atomic value
        if (bAtom)
        {
            sqlite3_value *vv = sqlite3_column_value(pp->pDataSource, JSON_TREE_VALUE);
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

/*
 * Updates or inserts array of objects
 * By convention, at the time of call, pDataSource is positioned at first object row (type == 'object')
 */
static int
_upsertObjectArray(_UpsertParams_t *pp)
{
    int result;

    // Iterate over all items until parent == parent or parent == id
    int currentScope = sqlite3_column_int(pp->pDataSource, JSON_TREE_ID);

    while ((result = sqlite3_step(pp->pDataSource)) == SQLITE_ROW)
    {
        int currentParent = sqlite3_column_int(pp->pDataSource, JSON_TREE_PARENT);
        int currentID = sqlite3_column_int(pp->pDataSource, JSON_TREE_ID);
        if (currentParent != pp->parent && currentID != currentScope)
            break;
        CHECK_CALL(_upsertObject(pp, 0));

    }

    if (result != SQLITE_DONE && result != SQLITE_ROW)
        goto ONERROR;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:
    EXIT:
    return result;
}

// TODO ???
static int
_getProp(_UpsertParams_t *pp, flexi_Object_t *obj)
{
    int result;

    int thisId = sqlite3_column_int(pp->pDataSource, JSON_TREE_ID);
    int thisParent = sqlite3_column_int(pp->pDataSource, JSON_TREE_PARENT);


    result = SQLITE_OK;

    return result;
}

static int
_saveObject(_UpsertParams_t *pp, sqlite3_int64 lExpectedObjectID, flexi_Object_t *obj)
{
    int result;
    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;
}

/*
 * Process top level object in _upsertOrDelete function
 */
static int
_upsertObject(_UpsertParams_t *pp, sqlite3_int64 lExpectedObjectID)
{
    int result;

    pp->level++;

    int objectScopeId = sqlite3_column_int(pp->pDataSource, JSON_TREE_ID);
    int savedParent = pp->parent;
    pp->parent = objectScopeId;

    // Init [.objects] row
    // TODO

    flexi_Object_t obj;
    flexi_Object_init(&obj, pp->dataVTab->pCtx);

    while ((result = sqlite3_step(pp->pDataSource)) == SQLITE_ROW)
    {
        result = (_upsertProperty(pp));
        if (result == SQLITE_DONE)
            break;

        CHECK_CALL(result);
    }

    // Save object
    if (pp->level == 1)
    {
        // Verify $id
        if (lExpectedObjectID != 0)
        {
            //            flexi_Object_getExistingPropByID()
        }
        CHECK_CALL(_saveObject(pp, lExpectedObjectID, &obj));
    }

    if (result != SQLITE_DONE)
        goto ONERROR;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    pp->level--;

    flexi_Object_clear(&obj);
    pp->parent = savedParent;
    return result;
}

/*
 *
 */
static int
_upsertData(_UpsertParams_t *pp)
{
    int result;
    int parent = sqlite3_column_int(pp->pDataSource, JSON_TREE_PARENT);
    bool bAtom = sqlite3_column_int(pp->pDataSource, JSON_TREE_ATOM) == 0;
    if (bAtom)
    {

    }
    else
    {
        const char *zType = (const char *) sqlite3_column_text(pp->pDataSource, JSON_TREE_TYPE);
        if (strcmp(zType, "array") == 0)
        {
            CHECK_CALL(_upsertObjectArray(pp));
        }
        else
            if (strcmp(zType, "object") == 0)
            {

            }
            else
            {
                result = SQLITE_ERROR;
                flexi_Context_setError(pp->dataVTab->pCtx, result, sqlite3_mprintf("Invalid token type %s", zType));
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

 First row in result of json_tree will have parent null. This is specilal item.
 It can be array or object (of given class)
 */
static int _upsertOrDelete(sqlite3_vtab *pVTab, int argc, sqlite3_value **argv, sqlite_int64 *pRowid)
{
    int result;

    sqlite3_stmt *pDataSource = NULL; // Parsed JSON data

    FlexiDataProxyVTab_t *dataVTab = (void *) pVTab;
    JsonProcessor_t jsonProc;
    JsonProcessor_init(&jsonProc, dataVTab->pCtx);

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
    {
        sqlite3_int64 lObjectID = sqlite3_value_int64(argv[1]);
        CHECK_CALL(flexi_DataDeleteObject(dataVTab, zClassName, lObjectID));
    }
    else
    {
        JsonProcessor_parse(&jsonProc, (const char *) sqlite3_value_text(argv[FLEXI_DATA_COL_DATA + 2]));

        _UpsertParams_t pp = {};
        pp.pDataSource = pDataSource;
        pp.lExpectedClassID = pClassDef->lClassID;
        pp.dataVTab = dataVTab;
        pp.insert = argv[0] == NULL;

        // Data will be in argv[9]
        // Class name will be in argv[3]
        bool insert = argv[0] == NULL;

        if (!pp.insert && sqlite3_value_type(argv[1]) == SQLITE_NULL)
        {
            result = SQLITE_ERROR;
            flexi_Context_setError(dataVTab->pCtx, result,
                                   sqlite3_mprintf("No object ID is passed for update operation"));
            goto ONERROR;
        }

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
                                   "fullkey, " // 6 todo needed?
                                   "path " // 7
                                   "from json_tree(:1);", &pDataSource);
        CHECK_CALL(sqlite3_bind_text(pDataSource, 1,
                                     (const char *) sqlite3_value_text(argv[FLEXI_DATA_COL_DATA + 2]), -1,
                                     NULL));
        result = sqlite3_step(pDataSource);
        if (result == SQLITE_ROW)
        {

            int scopeID = sqlite3_column_int(pDataSource, JSON_TREE_ID);
            pp.parent = scopeID;

            // First row is only used for determining data processing flow.
            char *zType = (char *) sqlite3_column_text(pDataSource, JSON_TREE_TYPE);
            if (strcmp(zType, "object") == 0)
            {
                CHECK_STMT_STEP(pDataSource, dataVTab->pCtx->db);
                CHECK_CALL(_upsertObject(&pp, lObjectID));
            }
            else
                if (strcmp(zType, "array") == 0)
                {
                    if (!insert)
                    {
                        result = SQLITE_ERROR;
                        flexi_Context_setError(dataVTab->pCtx, result,
                                               sqlite3_mprintf("Cannot update array of objects"));
                        goto ONERROR;
                    }

                    CHECK_STMT_STEP(pDataSource, dataVTab->pCtx->db);
                    CHECK_CALL(_upsertObjectArray(&pp));
                }
                else
                {
                    result = SQLITE_ERROR;
                    flexi_Context_setError(dataVTab->pCtx, result,
                                           sqlite3_mprintf("Data is expected to be object or array"));
                    goto ONERROR;
                }
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
    JsonProcessor_clear(&jsonProc);
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
 * TODO needed?
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
        .xUpdate = _upsertOrDelete,
        .xBegin = NULL,
        .xSync = NULL,
        .xCommit= NULL,
        .xRollback = NULL,
        .xFindFunction = _find_method,
        .xRename = _rename,
        .xSavepoint = NULL,
        .xRelease = NULL
};

