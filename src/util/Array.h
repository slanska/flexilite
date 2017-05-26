//
// Created by slanska on 2017-02-11.
//

#ifndef FLEXILITE_ARRAY_H
#define FLEXILITE_ARRAY_H

#include <stddef.h>
#include "../common/common.h"

/*
 * Implementation of generic array with items of fixed size
 */
typedef struct Array_t
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
     * Allocated number of items
     */
    u32 iCapacity;

    /*
     * Optional callback to dispose element
     */
    void (*disposeElem)(void *pElem);

    /*
    * Item size
    */
    size_t iElemSize;

    /*
     * Number of references to this array
     */
    int nRefCount;

    /*
     * If true, items are in staticData. No additional memory was allocated
     */
    bool bStatic;

    char staticData[64];
} Array_t;

extern Array_t *Array_new(size_t elemSize, void (*disposeElem)(void *pElem));

extern void Array_dispose(Array_t *self);

extern void Array_init(Array_t *self, size_t elemSize, void (*disposeElem)(void *pElem));

/*
 * Removes and cleans all items
 */
extern void Array_clear(Array_t *self);

/*
 * Returns pointer to item by given index
 * index: >=0 and < iCnt
 */
extern void *Array_getNth(Array_t *self, u32 index);

/*
 * Updates or appends an item to the array
 * index: can be between 0 and iCnt
 * pElem: if NULL, new item will be filled with zeros, otherwise, pElem content will be copied to a new item
 */
extern void Array_setNth(Array_t *self, u32 index, void *pElem);

/*
 * Appends new zeroed item to the end of array.
 * Returns pointer to a new item body
 */
extern void *Array_append(Array_t *self);

/*
 * Iterates over all items in array.
 * If iteratee sets bStop to true, iteration stops and address of last processed item is returned.
 * If all items were successfully processed, NULL is returned
 */
extern var Array_each(const Array_t *self, iterateeFunc iteratee, var param);

/*
 * Removes and cleans item at position index
 * index: must be >= 0 and < iCnt
 */
extern void Array_remove(Array_t *self, u32 index);

/*
 * Increases iRefCount of array
 */
extern void Array_ref(Array_t *pDestArray, Array_t *pSrcBufArray);

/*
 * Decreases iRefCount of array. If iRefCount riches 0, array will be cleaned and freed
 */
extern void Array_unref(Array_t *self);

#endif //FLEXILITE_ARRAY_H
