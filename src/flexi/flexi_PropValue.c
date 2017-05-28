//
// Created by slanska on 2017-05-22.
//

#include "flexi_PropValue.h"

int flexi_PropValue_init(flexi_PropValue_t *self, flexi_Context_t *pCtx, enum PROP_VALUE_KIND eValKind)
{
    memset(self, 0, sizeof(flexi_PropValue_t));
    self->pCtx = pCtx;
    self->eValKind = eValKind;
    switch (eValKind)
    {
        case PV_KIND_ATOM:
            self->pValue = NULL;
            break;

        case PV_KIND_ATOM_ARRAY:
            self->pList = Array_new(sizeof(sqlite3_value *), (void *) sqlite3_value_free);
            break;

        case PV_KIND_OBJECT_ARRAY:
            self->pList = Array_new(sizeof(flexi_Object_t *), (void *) flexi_Object_free);

            break;

        case PV_KIND_OBJECT:
            self->pObject = NULL;
            break;
    }
    return SQLITE_OK;
}

int flexi_PropValue_clear(flexi_PropValue_t *self)
{
    switch (self->eValKind)
    {
        case PV_KIND_OBJECT:
            flexi_Object_free(self->pObject);
            self->pObject = NULL;
            break;

        case PV_KIND_ATOM_ARRAY:
        case PV_KIND_OBJECT_ARRAY:
            Array_free(self->pList);
            self->pList = NULL;
            break;

        case PV_KIND_ATOM:
            sqlite3_value_free(self->pValue);
            self->pValue = NULL;
            break;
    }

    return SQLITE_OK;
}

flexi_PropValue_t *flexi_PropValue_new(struct flexi_Context_t *pCtx, enum PROP_VALUE_KIND eValKind)
{
    flexi_PropValue_t *result = sqlite3_malloc(sizeof(flexi_PropValue_t));
    if (result == NULL)
        return NULL;

    flexi_PropValue_init(result, pCtx, eValKind);

    return result;
}

void flexi_PropValue_free(flexi_PropValue_t *self)
{
    if (self != NULL)
    {
        flexi_PropValue_clear(self);
        sqlite3_free(self);
    }
}

sqlite3_value *flexi_PropValue_getNth(flexi_PropValue_t *self, u32 index)
{
    if (index < self->pValues.iCnt)
        return (sqlite3_value *) Array_getNth(&self->pValues, index);

    return NULL;
}

inline void flexi_PropValue_setNth(flexi_PropValue_t *self, u32 index, sqlite3_value *value)
{
    Array_setNth(&self->pValues, index, sqlite3_value_dup(value));
}

inline sqlite3_value *flexi_PropValue_get(flexi_PropValue_t *self)
{
    return flexi_PropValue_getNth(self, 0);
}

inline void flexi_PropValue_set(flexi_PropValue_t *self, sqlite3_value *value)
{
    Array_clear(&self->pValues);
    flexi_PropValue_setNth(self, 0, value);
}

bool flexi_PropValue_validate(flexi_PropValue_t *self)
{
    return SQLITE_OK;
}

