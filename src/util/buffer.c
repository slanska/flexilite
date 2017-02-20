//
// Created by slanska on 2017-02-11.
//

#include <string.h>
#include <assert.h>
#include "buffer.h"

#include <sqlite3ext.h>

SQLITE_EXTENSION_INIT3

void Buffer_init(Buffer *pBuf, size_t elemSize, void (*disposeElem)(void *pElem))
{
    memset(pBuf, 0, sizeof(*pBuf));

    pBuf->iElemSize = elemSize;
    pBuf->disposeElem = disposeElem;
}

void Buffer_done(Buffer *pBuf)
{
    if (pBuf->disposeElem)
    {
        int idx;
        char *pElem;
        for (idx = 0, pElem = pBuf->items; idx < pBuf->iCnt * pBuf->iElemSize; idx++,
                pElem += pBuf->iElemSize)
        {
            pBuf->disposeElem(pElem);
        }
    }
    sqlite3_free(pBuf->items);
    pBuf->items = 0;
    pBuf->iCapacity = 0;
    pBuf->iCnt = 0;
}

static int _buffer_ensure_capacity(Buffer *pBuf, u32 newCnt)
{
    if (newCnt > pBuf->iCapacity)
    {

        // Delta for grow is at least 10, or 10% of current capacity
        u32 newCap = (pBuf->iCnt >> 3 > 8 ? pBuf->iCnt >> 3 : 8) + pBuf->iCnt;
        if (newCap < newCnt)
            newCap = newCnt;

        void *newItems = sqlite3_malloc(newCap * (int) pBuf->iElemSize);
        if (!newItems)
            return SQLITE_NOMEM;
        memcpy(newItems, pBuf->items, pBuf->iElemSize * pBuf->iCnt);
        pBuf->items = newItems;
        pBuf->iCapacity = newCap;
    }
    return SQLITE_OK;
}

inline void *Buffer_get(Buffer *pBuf, u32 index)
{
    assert(index < pBuf->iCnt);
    void *result = &pBuf->items[pBuf->iElemSize * index];
    return result;
}

void Buffer_set(Buffer *pBuf, u32 index, void *pElem)
{
    assert(index <= pBuf->iCnt);
    bool grow = index == pBuf->iCnt;
    if (grow)
        _buffer_ensure_capacity(pBuf, index);
    void *pItem = Buffer_get(pBuf, index);
    if (!grow && pBuf->disposeElem)
    {
        pBuf->disposeElem(pItem);
    }
    memcpy(pItem, pElem, pBuf->iElemSize);
    if (grow)
        pBuf->iCnt++;
}

int Buffer_append(Buffer *pBuf, void *pElem)
{
    int result = _buffer_ensure_capacity(pBuf, pBuf->iCnt + 1);
    if (result != SQLITE_OK)
        return -1;
    void *pItem = Buffer_get(pBuf, pBuf->iCnt + 1);
    memcpy(pItem, pElem, pBuf->iElemSize);
    return pBuf->iCnt++;
}

var Buffer_each(Buffer *pBuf, iterateeFunc iteratee, var param)
{
    assert(pBuf);
    assert(iteratee);

    if (pBuf->iCnt <= 0)
        return NULL;

    bool bStop = false;

    char *pCur = pBuf->items;
    int idx = 0;
    while (idx < pBuf->iCnt)
    {
        iteratee(NULL, idx, pCur, pBuf, param, &bStop);
        if (bStop)
            return pCur;

        pCur += pBuf->iElemSize;
        idx++;
    }

    return NULL;
}

void Buffer_remove(Buffer *pBuf, u32 index)
{
    assert(pBuf);
    assert(0 <= index && index < pBuf->iCnt);
    char *pp = &pBuf->items[index * pBuf->iElemSize];
    if (pBuf->disposeElem)
        pBuf->disposeElem(pp);

    memcpy(pp, pp + pBuf->iElemSize, (pBuf->iCnt - index - 1) * pBuf->iElemSize);
    pBuf->iCnt--;
}


