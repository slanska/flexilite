//
// Created by slanska on 2017-05-22.
//

#ifndef FLEXILITE_FLEXI_PROPVALUE_H
#define FLEXILITE_FLEXI_PROPVALUE_H

#include "../project_defs.h"
#include "flexi_Object.h"

#ifdef __cplusplus
extern "C" {
#endif

// Forward declaration
typedef struct flexi_Object_t flexi_Object_t;

enum PROP_VALUE_KIND
{
    PV_KIND_ATOM = 0,
    PV_KIND_ATOM_ARRAY = 1,
    PV_KIND_OBJECT = 2,
    PV_KIND_OBJECT_ARRAY = 3
};

/*
 * Property Value module. Used by flexi_Object_t
 */
typedef struct flexi_PropValue_t
{
    sqlite3_int64 lClassID;
    flexi_Context_t *pCtx;
    sqlite3_int64 lObjectID;
    int32_t id;
    int32_t index;

    // TODO remove
    Array_t pValues;

    char *zName;
    enum PROP_VALUE_KIND eValKind;
    union
    {
        /*
         * Single atom value
         */
        sqlite3_value *pValue;

        /*
         * Atom and object values
         */
        Array_t *pList;

        /*
         * Single object
         */
        flexi_Object_t *pObject;
    };
} flexi_PropValue_t;

int flexi_PropValue_init(flexi_PropValue_t *self, flexi_Context_t *pCtx, enum PROP_VALUE_KIND eValKind);

int flexi_PropValue_clear(flexi_PropValue_t *self);

flexi_PropValue_t *flexi_PropValue_new(struct flexi_Context_t *pCtx, enum PROP_VALUE_KIND eValKind);

void flexi_PropValue_free(flexi_PropValue_t *self);

sqlite3_value *flexi_PropValue_getNth(flexi_PropValue_t *self, u32 index);

inline void flexi_PropValue_setNth(flexi_PropValue_t *self, u32 index, sqlite3_value *value);

inline sqlite3_value *flexi_PropValue_get(flexi_PropValue_t *self);

inline void flexi_PropValue_set(flexi_PropValue_t *self, sqlite3_value *value);

bool flexi_PropValue_validate(flexi_PropValue_t *self);

#ifdef __cplusplus
}
#endif

#endif //FLEXILITE_FLEXI_PROPVALUE_H
