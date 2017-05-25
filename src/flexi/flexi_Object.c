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
    HashTable_clear(&self->propsByIDs);
    HashTable_clear(&self->propsByNames);

    for (int ii = 0; ii < ARRAY_LEN(self->fxValues); ii++)
    {
        sqlite3_value_free(self->fxValues[ii]);
    }
}

/*
 *
 */
int flexi_Object_init(flexi_Object_t *self, struct flexi_Context_t *pCtx)
{
    int result = SQLITE_OK;

    memset(self, 0, sizeof(flexi_Object_t));
    self->pCtx = pCtx;
    HashTable_init(&self->propsByIDs, DICT_INT, (void*)flexi_PropValue_free);
    HashTable_init(&self->propsByNames, DICT_STRING, (void*)sqlite3_value_free);

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

int flexi_Object_getProp(flexi_Object_t *self,
                         int32_t iPropID, int32_t iPropIndex, sqlite3_value **pValue)
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