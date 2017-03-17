//
// Created by slanska on 2017-03-07.
//

#ifndef FLEXILITE_STRINGBUILDER_H
#define FLEXILITE_STRINGBUILDER_H

/* Objects */
#include <stdbool.h>
#include <stdint.h>

/* An instance of this object represents a JSON string
** under construction.  Really, this is a generic string accumulator
** that can be and is used to create strings other than JSON.
*/
struct StringBuilder
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

typedef struct StringBuilder StringBuilder;

/* Initialize the StringBuilder object
*/
void StringBuilder_init(StringBuilder *self /*, sqlite3_context *pCtx*/);

/* Append the N-byte string in zIn to the end of the StringBuilder string
** under construction.  Enclose the string in "..." and escape
** any double-quotes or backslash characters contained within the
** string.
*/
void StringBuilder_appendJsonElem(StringBuilder *self, const char *zIn, uint32_t N);

/* Append N bytes from zIn onto the end of the StringBuilder string.
*/
void StringBuilder_appendRaw(StringBuilder *self, const char *zInStr, uint32_t nInStrLen);

/* Free all allocated memory and reset the StringBuilder object back to its
** initial state.
*/
void StringBuilder_clear(StringBuilder *self);

#endif //FLEXILITE_STRINGBUILDER_H
