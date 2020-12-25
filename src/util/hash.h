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

#ifdef SQLITE_CORE

#include <sqlite3.h>

#else

#include <sqlite3ext.h>

SQLITE_EXTENSION_INIT3

#endif

#include <assert.h>
#include <memory.h>
#include "../common/common.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Forward declarations of structures. */
typedef struct Hash Hash;
typedef struct HashElem HashElem;

typedef void (*freeElem)(void *pElem);

typedef enum DICTIONARY_TYPE
{
    /*
     * Keys are case sensitive strings that will be disposed by HashTable
     */
            DICT_STRING = 0,

    /*
     * Keys are case insensitive strings that will be disposed by HashTable
     */
            DICT_STRING_IGNORE_CASE = 1,

    /*
    * Keys are integers
    */
            DICT_INT = 2,

    /*
    * Keys are case sensitive strings that will NOT be disposed by HashTable
    */
            DICT_STRING_NO_FREE = 3,

    /*
    * Keys are case insensitive strings that will NOT be disposed by HashTable
    */
            DICT_STRING_IGNORE_CASE_NO_FREE = 4
} DICTIONARY_TYPE;

/*
 * Union type for dictionary/hash key which combines integer and string
 */
typedef union DictionaryKey_t
{
    const char *pKey;
    sqlite3_int64 iKey;
} DictionaryKey_t;

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

    /*
     * Pointer to array of hash buckets. Every element in the array has pointer to
     * the first element in the bucket and number of elements in the bucket
     * The first element of the array
     * */
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

    DICTIONARY_TYPE eDictType;
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

    /* Key associated with this element: either string or int64 */
    DictionaryKey_t key;
};

/*
** Access routines.  To delete, insert a NULL pointer.
*/

/*
 * Initializes hash table. If freeElemFunc is NULL, hash table is assumed to hold sqlite3_value
 * and sqlite3_value_free will be used for disposing elements' data
 */
void HashTable_init(Hash *, DICTIONARY_TYPE dictType, freeElem freeElemFunc);

/*
 * Sets new value for key pKey
 */
void HashTable_set_v(Hash *, DictionaryKey_t key, sqlite3_value *pData);

void HashTable_set(Hash *, DictionaryKey_t key, void *pData);

sqlite3_value *HashTable_get_v(const Hash *, DictionaryKey_t key);

void *HashTable_get(const Hash *, DictionaryKey_t key);

/// @brief
/// @param self
/// @param iteratee
/// @param param
/// @return
void *HashTable_each(const Hash *self, iterateeFunc iteratee, var param);

void HashTable_clear(Hash *);

unsigned int HashTable_getStringHash(const char *key);

#ifdef __cplusplus
}
#endif

#endif /* _SQLITE_HASH_H_ */