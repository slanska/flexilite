//
// Created by slanska on 2017-03-03.
//

#include <string.h>
#include <sqlite3ext.h>
#include <assert.h>
#include "List.h"

SQLITE_EXTENSION_INIT3

#define NEXT_PTR(item, offset) ((void**)((char*)item + offset))

List_t *List_new(size_t offset, void (*disposeItem)(var item))
{
    List_t *result = sqlite3_malloc(sizeof(List_t));
    if (result)
    {
        List_init(result, offset, disposeItem);
    }
    return result;
}

void List_dispose(List_t *self)
{
    if (self)
    {
        List_clear(self);
        sqlite3_free(self);
    }
}

void List_init(List_t *self, size_t offset, void (*disposeItem)(var item))
{
    memset(self, 0, sizeof(*self));
    self->disposeItem = disposeItem;
    self->nextOffset = offset;
}

void List_clear(List_t *self)
{
    while (self->first)
    {
        var *p = NEXT_PTR(self->first, self->nextOffset);
        if (self->disposeItem)
        {
            self->disposeItem(self->first);
        }
        else
        {
            sqlite3_free(self->first);
        }

        self->first = *p;

    }
}

void List_add(List_t *self, var item)
{
    assert(item);
    var *p = NEXT_PTR(item, self->nextOffset);
    *p = self->first;
    self->first = item;
}

var List_each(List_t *self, iterateeFunc func, var args)
{
    var p = self->first;
    bool bStop = false;
    u32 idx = 0;
    while (p)
    {
        func(NULL, idx++, p, self, args, &bStop);
        if (bStop)
            return p;
        p = *NEXT_PTR(p, self->nextOffset);
    }

    return NULL;
}

void List_remove(List_t *self, var item)
{
    var *p = &self->first;
    while (*p)
    {
        if (*p == item)
        {
            *p = *NEXT_PTR(item, self->nextOffset);
            if (self->disposeItem)
            {
                self->disposeItem(item);
            }
            else
            {
                sqlite3_free(item);
            }
        }
    }
}

