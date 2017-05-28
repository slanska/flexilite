//
// Created by slanska on 2017-05-20.
//

/*
 * flexi_Object_t module: API for object data manipulation
 */

#include "flexi_Object.h"

static void
_reset(flexi_Object_t *self)
{
    HashTable_clear(&self->existingPropsByIDs);
    HashTable_clear(&self->newPropsByNames);
}

/*
 *
 */
int flexi_Object_init(flexi_Object_t *self, struct flexi_Context_t *pCtx)
{
    int result = SQLITE_OK;

    memset(self, 0, sizeof(flexi_Object_t));
    self->pCtx = pCtx;
    HashTable_init(&self->existingPropsByIDs, DICT_INT, (void *) sqlite3_value_free);
    HashTable_init(&self->newPropsByNames, DICT_STRING, (void *) flexi_PropValue_free);

    return result;
}

/*
 *
 */
flexi_Object_t *flexi_Object_new(struct flexi_Context_t *pCtx)
{
    flexi_Object_t *self = sqlite3_malloc(sizeof(flexi_Object_t));
    if (!self)
        return NULL;

    flexi_Object_init(self, pCtx);
    return self;
}

/*
 *
 */
int flexi_Object_clear(flexi_Object_t *self)
{
    int result = SQLITE_OK;
    _reset(self);
    return result;
}

/*
 *
 */
int flexi_Object_free(flexi_Object_t *self)
{
    if (self)
    {
        flexi_Object_clear(self);
        sqlite3_free(self);
    }

    return 0;
}

/*
 * Loads object data and non references properties
 */
int flexi_Object_load(flexi_Object_t *self, sqlite3_int64 lObjectID)
{
    int result;

    assert(self->pCtx);

    _reset(self);

    self->lObjectID = lObjectID;
    sqlite3_stmt *pOStmt;
    sqlite3_stmt *pRVStmt;

    // Load .objects
    CHECK_CALL(flexi_Context_stmtInit(self->pCtx, STMT_SEL_OBJ, "select "
            "* from [.objects] where ID=:1;", &pOStmt));
    sqlite3_bind_int64(pOStmt, 1, lObjectID);
    result = sqlite3_step(pOStmt);
    if (result == SQLITE_ROW)
    {

    }
    else
        if (result != SQLITE_DONE)
            goto ONERROR;

    // Load .ref-values
    CHECK_CALL(flexi_Context_stmtInit(self->pCtx, STMT_SEL_REF_VALUES, "select"
            ""
            " from [.ref-values] where ObjectID=:1;", &pRVStmt));

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;
}

/*
 * Validates object data. Returns SQLITE_OK if data is valid
 * Returns SQLITE_ERROR otherwise and sets specific error pzError
 * pzError should be set by sqlite3_mprintf, and to be deallocated by caller
 */
int flexi_Object_validate(flexi_Object_t *self, char **pzError)
{
    // Iterate through all properties
    int result;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:

    return result;
}

int flexi_Object_getNewPropByName(flexi_Object_t *self,
                                  const char *zPropName, u32 iPropIndex, sqlite3_value **pValue)
{
    int result;

    flexi_PropValue_t *prop = HashTable_get(&self->newPropsByNames, (DictionaryKey_t) {.pKey = zPropName});
    if (prop == NULL)
        return SQLITE_NOTFOUND;

    flexi_PropValue_getNth(prop, iPropIndex);

    result = SQLITE_OK;

    return result;
}

int flexi_Object_getExistingPropByID(flexi_Object_t *self,
                                     int32_t iPropID, u32 iPropIndex, sqlite3_value **pValue)
{
    int result;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:

    return result;
}

int flexi_Object_setProp(flexi_Object_t *self,
                         int32_t iPropID, int32_t iPropIndex, sqlite3_value *pValue)
{
    int result;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:

    return result;
}

/*
 * Validates data and inserts or updates object data in database
 */
int flexi_Object_save(flexi_Object_t *self)
{
    int result;

    // Validate

    // Log

    // .objects

    // .ref-values

    // .range-data

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;
}