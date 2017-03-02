//
// Created by slanska on 2017-02-11.
//

#ifndef FLEXILITE_BUFFER_H
#define FLEXILITE_BUFFER_H

#include <stddef.h>
#include "../common/common.h"

/*
 * Implementation of generic buffer with items of fixed size
 */
struct Buffer
{
    /*
     * Array of items
     */
    char *items;

    /*
     * Current number of items
     */
    u32 iCnt;

    /*
     * Item size
     */
    size_t iElemSize;

    /*
     * Allocated number of items
     */
    u32 iCapacity;

    /*
     * Optional callback to dispose element
     */
    void (*disposeElem)(void *pElem);

    /*
     * Number of references to this buffer
     */
    int nRefCount;
};

typedef struct Buffer Buffer;

extern Buffer *Buffer_new(size_t elemSize, void (*disposeElem)(void *pElem));

extern void Buffer_dispose(Buffer *pBuf);

extern void Buffer_init(Buffer *pBuf, size_t elemSize, void (*disposeElem)(void *pElem));

extern void Buffer_clear(Buffer *pBuf);

extern void *Buffer_get(Buffer *pBuf, u32 index);

extern void Buffer_set(Buffer *pBuf, u32 index, void *pElem);

extern void *Buffer_append(Buffer *pBuf);

extern var Buffer_each(const Buffer *pBuf, iterateeFunc iteratee, var param);

extern void Buffer_remove(Buffer *pBuf, u32 index);

extern void Buffer_ref(Buffer *pDestBuf, Buffer *pSrcBuf);

extern void Buffer_unref(Buffer *pBuf);

#endif //FLEXILITE_BUFFER_H
