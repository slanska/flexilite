/*
** 2001 September 22
**
** The author disclaims copyright to this source code.  In place of
** a legal notice, here is a blessing:
**
**    May you do good and not evil.
**    May you find forgiveness for yourself and forgive others.
**    May you share freely, never taking more than you give.
**
*************************************************************************
** This is the header file for the generic hash-table implementation
** used in SQLite.
*/
#ifndef _SQLITE_HASH_H_
#define _SQLITE_HASH_H_

//#include "../project_defs.h"

#include <sqlite3ext.h>

SQLITE_EXTENSION_INIT3

#include <assert.h>
#include <memory.h>
#include "../common/common.h"

/* Forward declarations of structures. */
typedef struct Hash Hash;
typedef struct HashElem HashElem;

typedef void (*freeElem)(void *pElem);

/* A complete hash table is an instance of the following structure.
** The internals of this structure are intended to be opaque -- client
** code should not attempt to access or modify the fields of this structure
** directly.  Change this structure only by using the routines below.
** However, some of the "procedures" and "functions" for modifying and
** accessing this structure are really macros, so we can't really make
** this structure opaque.
**
** All elements of the hash table are on a single doubly-linked list.
** Hash.first points to the head of this list.
**
** There are Hash.htsize buckets.  Each bucket points to a spot in
** the global doubly-linked list.  The contents of the bucket are the
** element pointed to plus the next _ht.count-1 elements in the list.
**
** Hash.htsize and Hash.ht may be zero.  In that case lookup is done
** by a linear search of the global list.  For small tables, the
** Hash.ht table is never allocated because if there are few elements
** in the table, it is faster to do a linear search than to manage
** the hash table.
*/
struct Hash
{
    unsigned int htsize;

    /* Number of buckets in the hash table */
    unsigned int count;

    /* Number of entries in this table */
    HashElem *first;

    /* The first element of the array */
    struct _ht
    {
        /* the hash table */
        int count;
        /* Number of entries with this hash */
        HashElem *chain;           /* Pointer to first entry with this hash */
    } *ht;

    /*
     * Custom callback to free element data
     */
    freeElem freeElemFunc;
};

/* Each element in the hash table is an instance of the following
** structure.  All elements are stored on a single doubly-linked list.
**
** Again, this structure is intended to be opaque, but it can't really
** be opaque because it is used by macros.
*/
struct HashElem
{
    /* Next and previous elements in the table */
    HashElem *next, *prev;

    /* Data associated with this element */
    var data;

    /* Key associated with this element */
    const char *pKey;
};

/*
** Access routines.  To delete, insert a NULL pointer.
*/

/*
 * Initializes hash table. If freeElemFunc is NULL, hash table is assumed to hold sqlite3_value
 * and sqlite3_value_free will be used for disposing elements' data
 */
void HashTable_init(Hash *, freeElem freeElemFunc);

/*
 * Sets new value for key pKey
 */
void HashTable_set_v(Hash *, const char *pKey, sqlite3_value *pData);

void HashTable_set(Hash *, const char *pKey, void *pData);

sqlite3_value *HashTable_get_v(const Hash *, const char *pKey);

void *HashTable_get(const Hash *, const char *pKey);

/// @brief
/// @param pH
/// @param iteratee
/// @param param
/// @return
void *HashTable_each(const Hash *pH, iterateeFunc iteratee, var param);

void HashTable_clear(Hash *);

unsigned int HashTable_getHash(const char *z);

#endif /* _SQLITE_HASH_H_ */