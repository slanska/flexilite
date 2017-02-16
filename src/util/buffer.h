//
// Created by slanska on 2017-02-11.
//

#ifndef FLEXILITE_BUFFER_H
#define FLEXILITE_BUFFER_H

//#include "../project_defs.h"
#include "../misc/json1.h"

/*
 * Implementation of generic buffer with items of fixed size
 */
struct Buffer {
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
};

typedef struct Buffer Buffer;

void buffer_init(Buffer *pBuf, size_t elemSize, void (*disposeElem)(void *pElem));

void buffer_done(Buffer *pBuf);

void *buffer_get(Buffer *pBuf, u32 index);

void buffer_set(Buffer *pBuf, u32 index, void *pElem);

int buffer_append(Buffer *pBuf, void *pElem);

#endif //FLEXILITE_BUFFER_H
