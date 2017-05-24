//
// Created by slanska on 2017-05-20.
//

#ifndef FLEXILITE_FLEXI_OBJECT_H
#define FLEXILITE_FLEXI_OBJECT_H

//#include "../project_defs.h"
#include "flexi_PropValue.h"

SQLITE_EXTENSION_INIT3

enum OBJ_FIXED_COLS
{
    OBJ_FX_COL_A = 0,
    OBJ_FX_COL_B = 1,
    OBJ_FX_COL_C = 2,
    OBJ_FX_COL_D = 3,
    OBJ_FX_COL_E = 4,
    OBJ_FX_COL_F = 5,
    OBJ_FX_COL_G = 6,
    OBJ_FX_COL_H = 7,
    OBJ_FX_COL_I = 8,
    OBJ_FX_COL_J = 9,
    OBJ_FX_COL_K = 10,
    OBJ_FX_COL_L = 11,
    OBJ_FX_COL_M = 12,
    OBJ_FX_COL_N = 13,
    OBJ_FX_COL_O = 14,
    OBJ_FX_COL_P = 15,

    OBJ_FX_COL_LAST = 15
};

typedef struct flexi_Object_t
{
    struct flexi_Context_t *pCtx;

    sqlite3_int64 lClassID;

    sqlite3_int64 lObjectID;

    bool insert;

    /*
     * Fixed(locked) column values
     */
    // TODO Needed?
    sqlite3_value *fxValues[OBJ_FX_COL_LAST + 1];

    /*
     * Property values - dictionary by int64 : propertyIndex << 32 | propertyID
     * to flexi_PropValue_t
     */
    Hash propValues;
} flexi_Object_t;

/*
 *
 */
int flexi_Object_init(flexi_Object_t *self, struct flexi_Context_t *pCtx);

/*
 *
 */
flexi_Object_t*  flexi_Object_new(struct flexi_Context_t *pCtx);

/*
 *
 */
int flexi_Object_clear(flexi_Object_t *self);

/*
 *
 */
int flexi_Object_free(flexi_Object_t *self);

/*
 * Loads object data and non references properties
 */
int flexi_Object_load(flexi_Object_t *self, sqlite3_int64 lObjectID);

/*
 * Validates object data. Returns SQLITE_OK if data is valid
 * Returns SQLITE_ERROR otherwise and sets specific error pzError
 * pzError should be set by sqlite3_mprintf, and to be deallocated by caller
 */
int flexi_Object_validate(flexi_Object_t *self, char **pzError);

int flexi_Object_getProp(flexi_Object_t *self,
                         int32_t iPropID, int32_t iPropIndex, sqlite3_value** pValue);

int flexi_Object_setProp(flexi_Object_t *self,
                         int32_t iPropID, int32_t iPropIndex, sqlite3_value* pValue);

/*
 * Validates data and inserts or updates object data in database
 */
int flexi_Object_save(flexi_Object_t *self);

#endif //FLEXILITE_FLEXI_OBJECT_H
