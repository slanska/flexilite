//
// Created by slanska on 2017-03-07.
//

#include <string.h>
#include <assert.h>
#include "Path.h"
#include "Array.h"
#include "StringBuilder.h"

#ifdef  _WIN32
#define PATH_SEPARATOR "\\"
#else
#define PATH_SEPARATOR "/"
#endif

typedef struct Token_t
{
    const char *zValue;
    size_t len;
} Token_t;

static void
_processSegment(const char *zKey, u32 idx, Token_t *pToken, Array_t *self, Array_t *pNewSegs, bool *bStop)
{
    UNUSED_PARAM(zKey);
    UNUSED_PARAM(idx);
    UNUSED_PARAM(self);
    UNUSED_PARAM(bStop);

    if (pToken->len == 0 || strncmp(pToken->zValue, ".", pToken->len) == 0)
        return;

    if (strncmp(pToken->zValue, "..", pToken->len) != 0)
    {
        Array_setNth(pNewSegs, pNewSegs->iCnt, pToken);
    }
    else
        if (pNewSegs->iCnt > 0)
        {
            Token_t *pNewTok = Array_getNth(pNewSegs, pNewSegs->iCnt - 1);
            pNewTok->len = 0;
            pNewSegs->iCnt--;
        }
}

static void
_concatenateSegment(const char *zKey, uint32_t idx, Token_t *pToken, Array_t *pNewSegs, StringBuilder *sb, bool *bStop)
{
    UNUSED_PARAM(zKey);
    UNUSED_PARAM(idx);
    UNUSED_PARAM(pNewSegs);
    UNUSED_PARAM(bStop);

    if (pToken->len == 0)
        return;

    StringBuilder_appendRaw(sb, PATH_SEPARATOR, (uint32_t)strlen(PATH_SEPARATOR));

    StringBuilder_appendRaw(sb, pToken->zValue, (int32_t) pToken->len);
}

void static
_splitPath(Array_t *segments, const char *zPath, const char chSeparator)
{
    Token_t token;
    token.len = 0;
    token.zValue = zPath;
    char *p = (char *) zPath;

    do
    {
        if (*p == '\0' || *p == chSeparator)
        {
            token.len = p - token.zValue;
            Array_setNth(segments, segments->iCnt, &token);
            token.len = 0;
            token.zValue = p + 1;

            if (*p == '\0')
                break;
        }

        p++;
    } while (true);
}

void Path_join(char **pzResult, const char *zBase, const char *zAddPath)
{
    assert(pzResult);

    // Split path parameters by '/'
    Array_t segments;
    Array_init(&segments, sizeof(Token_t), NULL);

    _splitPath(&segments, zBase, PATH_SEPARATOR[0]);
    _splitPath(&segments, zAddPath, '/');

    Array_t newSegs;
    Array_init(&newSegs, sizeof(Token_t), NULL);

    StringBuilder strBuf;
    StringBuilder_init(&strBuf);

    Array_each(&segments, (void *) _processSegment, &newSegs);

    Array_each(&newSegs, (void *) _concatenateSegment, &strBuf);

    *pzResult = sqlite3_malloc((int) strBuf.nUsed + 1);
    memcpy(*pzResult, strBuf.zBuf, strBuf.nUsed);
    (*pzResult)[strBuf.nUsed] = '\0';

    Array_clear(&segments);
    Array_clear(&newSegs);
    StringBuilder_clear(&strBuf);
}

void Path_dirname(char **pzResult, const char *zPath)
{
    Path_join(pzResult, zPath, "..");
}

#undef PATH_SEPARATOR
