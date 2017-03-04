//
// Created by slanska on 2017-03-03.
//


#ifndef FLEXILITE_LIST_H
#define FLEXILITE_LIST_H

#include <stddef.h>
#include "../common/common.h"

/*
 * Generic single linked list
 * Every item in the list should have pointer to next item, defined by offset
 */

typedef struct List_t
{
    var first;
    size_t nextOffset;

    void (*disposeItem)(var item);

    int count;
} List_t;

List_t *List_new(size_t offset, void (*disposeItem)(var item));

void List_dispose(List_t *self);

void List_init(List_t *self, size_t offset, void (*disposeItem)(var item));
void List_clear(List_t *self);
void List_add(List_t *self, var item);
var List_each(List_t *self, iterateeFunc func, var args);
void List_remove(List_t *self, var item);

#endif //FLEXILITE_LIST_H
