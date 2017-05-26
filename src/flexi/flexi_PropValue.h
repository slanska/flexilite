//
// Created by slanska on 2017-05-22.
//

#ifndef FLEXILITE_FLEXI_PROPVALUE_H
#define FLEXILITE_FLEXI_PROPVALUE_H

#include "../project_defs.h"
#include "flexi_Object.h"

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
    Array_t pValues;
    char *zName;
    enum PROP_VALUE_KIND eValKind;
    union
    {
        sqlite3_value *pValue;
        Array_t *pList;
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

#endif //FLEXILITE_FLEXI_PROPVALUE_H
