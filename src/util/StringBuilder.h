//
// Created by slanska on 2017-03-07.
//

#ifndef FLEXILITE_STRINGBUILDER_H
#define FLEXILITE_STRINGBUILDER_H

/* Objects */
#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* An instance of this object represents a JSON string
** under construction.  Really, this is a generic string accumulator
** that can be and is used to create strings other than JSON.
*/
struct StringBuilder_t
{

    /* Append JSON content here */
    char *zBuf;

    /* Bytes of storage available in zBuf[] */
    uint64_t nAlloc;

    /* Bytes of zBuf[] currently used */
    uint64_t nUsed;

    /* True if zBuf is static space */
    bool bStatic;

    /* True if an error has been encountered */
    bool bErr;

    /* Initial static space */
    char zSpace[100];
};

typedef struct StringBuilder_t StringBuilder_t;

/* Initialize the StringBuilder_t object
*/
void StringBuilder_init(StringBuilder_t *self /*, sqlite3_context *pCtx*/);

/* Append the N-byte string in zIn to the end of the StringBuilder_t string
** under construction.  Enclose the string in "..." and escape
** any double-quotes or backslash characters contained within the
** string.
** If N < 0, number of characters to take will be determined by strlen(zIn)
*/
void StringBuilder_appendJsonElem(StringBuilder_t *self, const char *zIn, int32_t N);

/* Append N bytes from zIn onto the end of the StringBuilder_t string.
 * If N < 0, zInStr is assumed to be a zero-terminated string and N will be determined using strlen
*/
void StringBuilder_appendRaw(StringBuilder_t *self, const char *zInStr, int32_t nInStrLen);

/* Free all allocated memory and reset the StringBuilder_t object back to its
** initial state.
*/
void StringBuilder_clear(StringBuilder_t *self);

/*
 * Calculates number of UTF-8 characters in the string.
 * Source: http://stackoverflow.com/questions/5117393/utf-8-strings-length-in-linux-c
 */
int get_utf8_len(const unsigned char *s);

#ifdef __cplusplus
}
#endif

#endif //FLEXILITE_STRINGBUILDER_H
