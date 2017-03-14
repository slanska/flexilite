//
// Created by slanska on 2017-02-11.
//

#include <string.h>
#include <assert.h>
#include "Array.h"

#ifdef SQLITE_CORE

#include <sqlite3.h>

#else

#include <sqlite3ext.h>

SQLITE_EXTENSION_INIT3

#endif

Array_t *Array_new(size_t elemSize, void (*disposeElem)(void *))
{
    Array_t *self;
    self = sqlite3_malloc(sizeof(*self));
    if (self != NULL)
    {
        Array_init(self, elemSize, disposeElem);
        self->nRefCount = 1;
    }
    return self;
}

void Array_dispose(Array_t *self)
{
    if (!self)
        return;

    Array_unref(self);
    if (self->nRefCount == 0)
        sqlite3_free(self);
}

void Array_init(Array_t *self, size_t elemSize, void (*disposeElem)(void *))
{
    memset(self, 0, sizeof(*self));

    self->iElemSize = elemSize;
    self->disposeElem = disposeElem;

    if (elemSize < sizeof(self->staticData))
    {
        self->iCapacity = sizeof(self->staticData) / elemSize;
        self->bStatic = true;
        self->items = self->staticData;
    }
}

void Array_clear(Array_t *self)
{
    if (self->disposeElem)
    {
        int idx;
        char *pElem = self->items;
        for (idx = 0; idx < self->iCnt; idx++)
        {
            self->disposeElem(pElem);
            pElem += self->iElemSize;
        }
    }

    if (!self->bStatic)
    {
        sqlite3_free(self->items);

        if (self->iElemSize < sizeof(self->staticData))
        {
            self->items = self->staticData;
            self->bStatic = true;
        }
        else self->items = NULL;
    }

    self->iCapacity = 0;
    self->iCnt = 0;
}

static int
_array_ensure_capacity(Array_t *self, u32 newCnt)
{
    if (newCnt > self->iCapacity)
    {
        u32 newCap = (self->iCnt >> 3 > 8 ? self->iCnt >> 3 : 8) + self->iCnt;
        if (newCap < newCnt)
            newCap = newCnt;

        void *newItems = sqlite3_malloc(newCap * (int) self->iElemSize);
        if (!newItems)
            return SQLITE_NOMEM;
        memcpy(newItems, self->items, self->iElemSize * self->iCnt);

        if (!self->bStatic)
        {
            sqlite3_free(self->items);
        }
        self->items = newItems;
        self->bStatic = false;
        self->iCapacity = newCap;
    }
    return SQLITE_OK;
}

inline void *Array_getNth(Array_t *self, u32 index)
{
    assert(index < self->iCnt);
    void *result = &self->items[self->iElemSize * index];
    return result;
}

void Array_setNth(Array_t *self, u32 index, void *pElem)
{
    assert(index <= self->iCnt);
    bool grow = index == self->iCnt;
    if (grow)
        _array_ensure_capacity(self, index + 1);

    if (grow)
        self->iCnt++;

    void *pItem = Array_getNth(self, index);
    if (!grow && self->disposeElem && (!pElem || memcmp(pItem, pElem, self->iElemSize) == 0))
    {
        self->disposeElem(pItem);
    }
    if (pElem)
        memcpy(pItem, pElem, self->iElemSize);
    else
        memset(pItem, 0, self->iElemSize);
}

void *Array_append(Array_t *self)
{
    int result = _array_ensure_capacity(self, self->iCnt + 1);
    if (result != SQLITE_OK)
        return NULL;
    void *pItem = Array_getNth(self, self->iCnt + 1);
    return pItem;
}

var Array_each(const Array_t *self, iterateeFunc iteratee, var param)
{
    assert(self);
    assert(iteratee);

    if (self->iCnt <= 0)
        return NULL;

    bool bStop = false;

    char *pCur = self->items;
    int idx = 0;
    while (idx < self->iCnt)
    {
        iteratee(NULL, idx, pCur, (void *) self, param, &bStop);
        if (bStop)
            return pCur;

        pCur += self->iElemSize;
        idx++;
    }

    return NULL;
}

void Array_remove(Array_t *self, u32 index)
{
    assert(self);
    assert(0 <= index && index < self->iCnt);
    char *pp = &self->items[index * self->iElemSize];
    if (self->disposeElem)
        self->disposeElem(pp);

    memcpy(pp, pp + self->iElemSize, (self->iCnt - index - 1) * self->iElemSize);
    self->iCnt--;
}

/*
 * Copies array
 */
void Array_ref(Array_t *pDestArray, Array_t *pSrcBufArray)
{
    assert(pSrcBufArray);
    if (pDestArray != pSrcBufArray)
    {
        memcpy(pDestArray, pSrcBufArray, sizeof(*pSrcBufArray));
    }
    pDestArray->nRefCount++;
}

/*
 * Unreferences array by decrementing ref count
 * If after decrement ref count becomes zero, array gets cleared
 */
void Array_unref(Array_t *self)
{
    assert(self);
    if (self->nRefCount > 0)
        self->nRefCount--;

    if (self->nRefCount == 0)
    {
        Array_clear(self);
    }
}
