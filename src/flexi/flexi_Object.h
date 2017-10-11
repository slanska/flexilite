//
// Created by slanska on 2017-05-20.
//

#ifndef FLEXILITE_FLEXI_OBJECT_H
#define FLEXILITE_FLEXI_OBJECT_H

#include "flexi_PropValue.h"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Structure for individual object data
 *
 */
typedef struct flexi_Object_t
{
    struct flexi_Context_t *pCtx;

    sqlite3_int64 lClassID;

    sqlite3_int64 lObjectID;

    bool insert;

    /*
     * Property values - dictionary by int64 : propertyIndex << 32 | propertyID
     * to flexi_PropValue_t
     */
    Hash existingPropsByIDs;

    /*
     * Raw property map - as it comes from input JSON.
     */
    Hash newPropsByNames;
} flexi_Object_t;

/*
 * Initializes object's instance
 */
int flexi_Object_init(flexi_Object_t *self, struct flexi_Context_t *pCtx);

/*
 *
 */
flexi_Object_t *flexi_Object_new(struct flexi_Context_t *pCtx);

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

int flexi_Object_getExistingPropByID(flexi_Object_t *self,
                                     int32_t iPropID, u32 iPropIndex, sqlite3_value **pValue);

int flexi_Object_getNewPropByName(flexi_Object_t *self,
                                  const char *zPropName, u32 iPropIndex, sqlite3_value **pValue);

int flexi_Object_setProp(flexi_Object_t *self,
                         int32_t iPropID, int32_t iPropIndex, sqlite3_value *pValue);

/*
 * Validates data and inserts or updates object data in database
 */
int flexi_Object_save(flexi_Object_t *self);

#ifdef __cplusplus
}
#endif

#endif //FLEXILITE_FLEXI_OBJECT_H
