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

/*
 * Removes and cleans all items
 */
extern void Buffer_clear(Buffer *pBuf);

/*
 * Returns pointer to item by given index
 * index: >=0 and < iCnt
 */
extern void *Buffer_get(Buffer *pBuf, u32 index);

/*
 * Updates or appends an item to the buffer
 * index: can be between 0 and iCnt
 * pElem: if NULL, new item will be filled with zeros, otherwise, pElem content will be copied to a new item
 */
extern void Buffer_set(Buffer *pBuf, u32 index, void *pElem);

/*
 * Appends new zeroed item to the end of buffer.
 * Returns pointer to a new item body
 */
extern void *Buffer_append(Buffer *pBuf);

/*
 * Iterates over all items in buffer.
 * If iteratee sets bStop to true, iteration stops and address of last processed item is returned.
 * If all items were successfully processed, NULL is returned
 */
extern var Buffer_each(const Buffer *pBuf, iterateeFunc iteratee, var param);

/*
 * Removes and cleans item at position index
 * index: must be >= 0 and < iCnt
 */
extern void Buffer_remove(Buffer *pBuf, u32 index);

/*
 * Increases iRefCount of buffer
 */
extern void Buffer_ref(Buffer *pDestBuf, Buffer *pSrcBuf);

/*
 * Decreases iRefCount of buffer. If iRefCount riches 0, buffer will be cleaned and freed
 */
extern void Buffer_unref(Buffer *pBuf);

#endif //FLEXILITE_BUFFER_H
