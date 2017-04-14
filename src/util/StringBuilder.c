//
// Created by slanska on 2017-03-07.
//

#include <string.h>
#include <assert.h>

#include "StringBuilder.h"

#ifdef  SQLITE_CORE

#include <sqlite3.h>

#else

#include <sqlite3ext.h>

SQLITE_EXTENSION_INIT3

#endif

/*
 * Set the StringBuilder_t object to an empty string
*/
static void
_zero(StringBuilder_t *self)
{
    self->zBuf = self->zSpace;
    self->nAlloc = sizeof(self->zSpace);
    self->nUsed = 0;
    self->bStatic = true;
}

void StringBuilder_init(StringBuilder_t *self)
{
    memset(self, 0, sizeof(*self));
    self->bErr = false;
    _zero(self);
}

/* Enlarge self->zBuf so that it can hold at least N more bytes.
** Return zero on success.  Return non-zero on an OOM error
*/
static int
_grow(StringBuilder_t *self, uint32_t N)
{
    sqlite3_uint64 nTotal = N < self->nAlloc ? self->nAlloc * 2 : self->nAlloc + N + 10;
    char *zNew;
    if (self->bStatic)
    {
        if (self->bErr) return 1;
        zNew = sqlite3_malloc64(nTotal);
        if (zNew == 0)
        {
            return SQLITE_NOMEM;
        }
        memcpy(zNew, self->zBuf, (size_t) self->nUsed);
        self->zBuf = zNew;
        self->bStatic = 0;
    }
    else
    {
        zNew = sqlite3_realloc64(self->zBuf, nTotal);
        if (zNew == 0)
        {
            return SQLITE_NOMEM;
        }
        self->zBuf = zNew;
    }
    self->nAlloc = nTotal;
    return SQLITE_OK;
}

/* Append N bytes from zIn onto the end of the StringBuilder_t string.
*/
void StringBuilder_appendRaw(StringBuilder_t *self, const char *zInStr, int32_t nInStrLen)
{
    if (nInStrLen < 0)
        nInStrLen = (int32_t) strlen(zInStr);

    if ((nInStrLen + self->nUsed >= self->nAlloc) && _grow(self, nInStrLen) != 0)
        return;
    memcpy(self->zBuf + self->nUsed, zInStr, nInStrLen);
    self->nUsed += nInStrLen;
}

/* Append a single character
*/
static void
_appendChar(StringBuilder_t *p, char c)
{
    if (p->nUsed >= p->nAlloc && _grow(p, 1) != 0)
        return;
    p->zBuf[p->nUsed++] = c;
}

/* Free all allocated memory and reset the StringBuilder_t object back to its
** initial state.
*/
void StringBuilder_clear(StringBuilder_t *self)
{
    if (!self->bStatic)
        sqlite3_free(self->zBuf);
    _zero(self);
}

/* Append the N-byte string in zIn to the end of the StringBuilder_t string
** under construction.  Enclose the string in "..." and escape
** any double-quotes or backslash characters contained within the
** string.
** If N < 0, number of characters to take will be determined by strlen(zIn)
*/
void StringBuilder_appendJsonElem(StringBuilder_t *p, const char *zIn, int32_t N)
{
    uint32_t i;

    if (N < 0)
        N = strlen(zIn);

    if ((N + p->nUsed + 2 >= p->nAlloc) && _grow(p, N + 2) != 0) return;
    p->zBuf[p->nUsed++] = '"';
    for (i = 0; i < N; i++)
    {
        unsigned char c = ((unsigned const char *) zIn)[i];
        if (c == '"' || c == '\\')
        {
            json_simple_escape:
            if ((p->nUsed + N + 3 - i > p->nAlloc) && _grow(p, N + 3 - i) != 0) return;
            p->zBuf[p->nUsed++] = '\\';
        }
        else
            if (c <= 0x1f)
            {
                static const char aSpecial[] = {
                        0, 0, 0, 0, 0, 0, 0, 0, 'b', 't', 'n', 0, 'f', 'r', 0, 0,
                        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                };
                assert(sizeof(aSpecial) == 32);
                assert(aSpecial['\b'] == 'b');
                assert(aSpecial['\f'] == 'f');
                assert(aSpecial['\n'] == 'n');
                assert(aSpecial['\r'] == 'r');
                assert(aSpecial['\t'] == 't');
                if (aSpecial[c])
                {
                    c = (unsigned char) aSpecial[c];
                    goto json_simple_escape;
                }
                if ((p->nUsed + N + 7 + i > p->nAlloc) && _grow(p, N + 7 - i) != 0) return;
                p->zBuf[p->nUsed++] = '\\';
                p->zBuf[p->nUsed++] = 'u';
                p->zBuf[p->nUsed++] = '0';
                p->zBuf[p->nUsed++] = '0';
                p->zBuf[p->nUsed++] = (char) ('0' + (c >> 4));
                c = (unsigned char) ("0123456789abcdef"[c & 0xf]);
            }
        p->zBuf[p->nUsed++] = c;
    }
    p->zBuf[p->nUsed++] = '"';
    assert(p->nUsed < p->nAlloc);
}
