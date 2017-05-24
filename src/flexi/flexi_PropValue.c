//
// Created by slanska on 2017-05-22.
//

#include "flexi_PropValue.h"

int flexi_PropValue_init(flexi_PropValue_t *self, flexi_Context_t *pCtx)
{
    memset(self, 0, sizeof(flexi_PropValue_t));
    Array_init(&self->pValues, sizeof(sqlite3_value *), (void *) sqlite3_value_free);
    self->pCtx = pCtx;
    return SQLITE_OK;
}

int flexi_PropValue_clear(flexi_PropValue_t *self)
{
    Array_clear(&self->pValues);
    return SQLITE_OK;
}

flexi_PropValue_t *flexi_PropValue_new(flexi_Context_t *pCtx)
{
    flexi_PropValue_t *result = sqlite3_malloc(sizeof(flexi_PropValue_t));
    if (result == NULL)
        return NULL;

    flexi_PropValue_init(result, pCtx);

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
    if (index >= 0 && index < self->pValues.iCnt)
        return (sqlite3_value*)Array_getNth(&self->pValues, index);

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

