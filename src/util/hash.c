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
** This is the implementation of generic hash-tables
** used in SQLite.
 *
 * [slanska] This code has been modified to be used as a generic hash table (with arbitrary value type,
 * not only sqlite3_value)
*/
#include "hash.h"



/* Turn bulk memory into a hash table object by initializing the
** fields of the Hash structure.
**
** "pNew" is a pointer to the hash table that is to be initialized.
*/
void HashTable_init(Hash *pNew, freeElem freeElemFunc)
{
    assert(pNew != 0);
    pNew->first = 0;
    pNew->count = 0;
    pNew->htsize = 0;
    pNew->ht = 0;
    if (freeElemFunc)
        pNew->freeElemFunc = freeElemFunc;
    else pNew->freeElemFunc = (void *) sqlite3_value_free;
}


/* Remove all entries from a hash table.  Reclaim all memory.
** Call this routine to delete a hash table or to reset a hash table
** to the empty state.
*/
void HashTable_clear(Hash *pH)
{
    HashElem *elem;         /* For looping over all elements of the table */

    assert(pH != 0);
    elem = pH->first;
    pH->first = 0;
    sqlite3_free(pH->ht);
    pH->ht = NULL;
    pH->htsize = 0;
    while (elem)
    {
        HashElem *next_elem = elem->next;
        // TODO       sqlite3_value_free(elem->data);
        pH->freeElemFunc(elem->data);
        sqlite3_free((void *) elem->pKey);
        sqlite3_free(elem);
        elem = next_elem;
    }
    pH->count = 0;
}


/*
** The hashing function.
*/
unsigned int HashTable_getHash(const char *z)
{
    unsigned int h = 0;
    unsigned char c;
    while ((c = (unsigned char) *z++) != 0)
    {
        h = (h << 3) ^ h ^ c;
    }
    return h;
}


/* Link pNew element into the hash table pH.  If pEntry!=0 then also
** insert pNew into the pEntry hash bucket.
*/
static void _insertElement(
        Hash *pH,              /* The complete hash table */
        struct _ht *pEntry,    /* The entry into which pNew is inserted */
        HashElem *pNew         /* The element to be inserted */
)
{
    HashElem *pHead;       /* First element already in pEntry */
    if (pEntry)
    {
        pHead = pEntry->count ? pEntry->chain : 0;
        pEntry->count++;
        pEntry->chain = pNew;
    }
    else
    {
        pHead = 0;
    }
    if (pHead)
    {
        pNew->next = pHead;
        pNew->prev = pHead->prev;
        if (pHead->prev)
        { pHead->prev->next = pNew; }
        else
        { pH->first = pNew; }
        pHead->prev = pNew;
    }
    else
    {
        pNew->next = pH->first;
        if (pH->first)
        { pH->first->prev = pNew; }
        pNew->prev = 0;
        pH->first = pNew;
    }
}

/* Resize the hash table so that it contains "new_size" buckets.
**
** The hash table might fail to resize if sqlite3_malloc() fails or
** if the new size is the same as the prior size.
** Return TRUE if the resize occurs and false if not.
*/
static int _rehash(Hash *pH, unsigned int new_size)
{
    struct _ht *new_ht;            /* The new hash table */
    HashElem *elem, *next_elem;    /* For looping over existing elements */

#if SQLITE_MALLOC_SOFT_LIMIT > 0
    if( new_size*sizeof(struct _ht)>SQLITE_MALLOC_SOFT_LIMIT ){
    new_size = SQLITE_MALLOC_SOFT_LIMIT/sizeof(struct _ht);
  }
  if( new_size==pH->htsize ) return 0;
#endif

    /* The inability to allocates space for a larger hash table is
    ** a performance hit but it is not a fatal error.  So mark the
    ** allocation as a benign. Use sqlite3Malloc()/memset(0) instead of
    ** sqlite3MallocZero() to make the allocation, as sqlite3MallocZero()
    ** only zeroes the requested number of bytes whereas this module will
    ** use the actual amount of space allocated for the hash table (which
    ** may be larger than the requested amount).
    */

    new_ht = (struct _ht *) sqlite3_malloc(new_size * sizeof(struct _ht));

    if (new_ht == 0) return 0;
    sqlite3_free(pH->ht);
    pH->ht = (void *) new_ht;

    pH->htsize = new_size = (unsigned int) sqlite3_msize(new_ht) / sizeof(struct _ht);
    memset(new_ht, 0, new_size * sizeof(struct _ht));
    for (elem = pH->first, pH->first = 0; elem; elem = next_elem)
    {
        unsigned int h = HashTable_getHash(elem->pKey) % new_size;
        next_elem = elem->next;
        _insertElement(pH, &new_ht[h], elem);
    }
    return 1;
}

/* This function (for internal use only) locates an element in an
** hash table that matches the given key.  The hash for this key is
** also computed and returned in the *pH parameter.
*/
static HashElem *_findElementWithHash(
        const Hash *pH,     /* The pH to be searched */
        const char *pKey,   /* The key we are searching for */
        unsigned int *pHash /* Write the hash value here */
)
{
    HashElem *elem;                /* Used to loop thru the element list */
    int count;                     /* Number of elements left to test */
    unsigned int h;                /* The computed hash */

    if (pH->ht)
    {
        struct _ht *pEntry;
        h = HashTable_getHash(pKey) % pH->htsize;
        pEntry = (void *) &pH->ht[h];
        elem = pEntry->chain;
        count = pEntry->count;
    }
    else
    {
        h = 0;
        elem = pH->first;
        count = pH->count;
    }
    *pHash = h;
    while (count--)
    {
        assert(elem != 0);

//        TODO sqlite3_stricmp()
        if (strcmp(elem->pKey, pKey) == 0)
        {
            return elem;
        }
        elem = elem->next;
    }
    return 0;
}

/* Remove a single entry from the hash table given a pointer to that
** element and a hash on the element's key.
*/
static void _removeElementGivenHash(
        Hash *pH,         /* The pH containing "elem" */
        HashElem *elem,   /* The element to be removed from the pH */
        unsigned int h    /* Hash value for the element */
)
{
    struct _ht *pEntry;
    if (elem->prev)
    {
        elem->prev->next = elem->next;
    }
    else
    {
        pH->first = elem->next;
    }
    if (elem->next)
    {
        elem->next->prev = elem->prev;
    }
    if (pH->ht)
    {
        pEntry = (void *) &pH->ht[h];
        if (pEntry->chain == elem)
        {
            pEntry->chain = elem->next;
        }
        pEntry->count--;
        assert(pEntry->count >= 0);
    }

    // TODO   sqlite3_value_free(elem->data);
    pH->freeElemFunc(elem->data);
    sqlite3_free((void *) elem->pKey);
    sqlite3_free(elem);

    pH->count--;
    if (pH->count == 0)
    {
        assert(pH->first == 0);
        assert(pH->count == 0);
        HashTable_clear(pH);
    }
}

/* Attempt to locate an element of the hash table pH with a key
** that matches pKey.  Return the data for this element if it is
** found, or NULL if there is no match.
*/
void *HashTable_get(const Hash *pH, const char *pKey)
{
    HashElem *elem;    /* The element that matches key */
    unsigned int h;    /* A hash on key */

    assert(pH != 0);
    assert(pKey != 0);
    elem = _findElementWithHash(pH, pKey, &h);
    return elem ? elem->data : 0;
}

inline void HashTable_set_v(Hash *pH, const char *pKey, sqlite3_value *pData)
{
    HashTable_set(pH, pKey, pData);
}

inline sqlite3_value *HashTable_get_v(const Hash *pH, const char *pKey)
{
    return (sqlite3_value *) HashTable_get(pH, pKey);
}

/* Insert an element into the hash table pH.  The key is pKey
** and the data is "data".
**
** If no element exists with a matching key, then a new
** element is created and NULL is returned.
**
** If another element already exists with the same key, then the
** new data replaces the old data and the old data is returned.
** The key is not copied in this instance.  If a malloc fails, then
** the new data is returned and the hash table is unchanged.
**
** If the "data" parameter to this function is NULL, then the
** element corresponding to "key" is removed from the hash table.
*/
void HashTable_set(Hash *pH, const char *pKey, void *data)
{
    unsigned int h;       /* the hash of the key modulo hash table size */
    HashElem *elem;       /* Used to loop thru the element list */

    assert(pH != 0);
    assert(pKey != 0);
    elem = _findElementWithHash(pH, pKey, &h);
    if (elem)
    {
        // If new data is null, delete existing entry
        if (data == NULL)
        {
            _removeElementGivenHash(pH, elem, h);
        }
        else
        {
            if (elem->data != data)
            {
                //  TODO              sqlite3_value_free(elem->data);
                pH->freeElemFunc(elem->data);
                elem->data = data;
            }

            if (elem->pKey != pKey)
            {
                sqlite3_free((void *) elem->pKey);
                elem->pKey = pKey;
            }
        }
        return;
    }

    if (data == NULL)
        return;
    /* New element added to the pH */
    HashElem *new_elem = (HashElem *) sqlite3_malloc(sizeof(HashElem));
    if (new_elem == NULL)
        return;
    new_elem->pKey = pKey;
    new_elem->data = data;
    pH->count++;
    if (pH->count >= 10 && pH->count > 2 * pH->htsize)
    {
        if (_rehash(pH, pH->count * 2))
        {
            assert(pH->htsize > 0);
            h = HashTable_getHash(pKey) % pH->htsize;
        }
    }
    _insertElement(pH, (void *) (pH->ht ? &pH->ht[h] : 0), new_elem);
    return;
}

void *HashTable_each(const Hash *pH, iterateeFunc iteratee)
{
    HashElem *elem;         /* For looping over all elements of the table */

    assert(pH != 0);
    assert(iteratee);
    int index = 0;

    bool bStop = false;
    elem = pH->first;
    while (elem)
    {
        iteratee(elem->pKey, index, elem->data, (var)pH, &bStop);
        if (bStop)
            return elem->data;

        elem = elem->next;
        index++;
    }

    return NULL;
}
