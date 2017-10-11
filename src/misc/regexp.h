//
// Created by slanska on 2016-04-11.
// Extracted from regexp.c to be re-used by other modules
//

#ifndef SQLITE_EXTENSIONS_REGEXP_H
#define SQLITE_EXTENSIONS_REGEXP_H

#include <string.h>

#include "../../lib/sqlite/sqlite3ext.h"

#ifdef __cplusplus
extern "C" {
#endif

SQLITE_EXTENSION_INIT3

/*
** The following #defines change the names of some functions implemented in
** this file to prevent name collisions with C-library functions of the
** same name.
*/
#define re_match   sqlite3re_match
#define re_compile sqlite3re_compile
#define re_free    sqlite3re_free

/* An input string read one character at a time.
*/
typedef struct ReInput ReInput;
struct ReInput
{
    const unsigned char *z;
    /* All text */
    int i;
    /* Next byte to read */
    int mx;                  /* EOF when i>=mx */
};

/* A compiled NFA (or an NFA that is in the process of being compiled) is
** an instance of the following object.
*/
typedef struct ReCompiled ReCompiled;

struct ReCompiled
{
    ReInput sIn;
    /* Regular expression text */
    const char *zErr;
    /* Error message to return */
    char *aOp;
    /* Operators for the virtual machine */
    int *aArg;

    /* Arguments to each operator */
    unsigned (*xNextChar)(ReInput *);

    /* Next character function */
    unsigned char zInit[12];
    /* Initial text to match */
    int nInit;
    /* Number of characters in zInit */
    unsigned nState;
    /* Number of entries in aOp[] and aArg[] */
    unsigned nAlloc;            /* Slots allocated for aOp[] and aArg[] */
};

/*
** Compile a textual regular expression in zIn[] into a compiled regular
** expression suitable for us by re_match() and return a pointer to the
** compiled regular expression in *ppRe.  Return NULL on success or an
** error message if something goes wrong.
*/
const char *re_compile(ReCompiled **ppRe, const char *zIn, int noCase);

/* Run a compiled regular expression on the zero-terminated input
** string zIn[].  Return true on a match and false if there is no match.
*/
int re_match(ReCompiled *pRe, const unsigned char *zIn, int nIn);

/* Free and reclaim all the memory used by a previously compiled
** regular expression.  Applications should invoke this routine once
** for every call to re_compile() to avoid memory leaks.
*/
void re_free(ReCompiled *pRe);

#ifdef __cplusplus
}
#endif

#endif //SQLITE_EXTENSIONS_REGEXP_H
