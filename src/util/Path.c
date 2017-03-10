//
// Created by slanska on 2017-03-07.
//

#include <string.h>
#include <assert.h>
#include "Path.h"
#include "Array.h"
#include "StringBuilder.h"

#if defined( _WIN32 ) || defined( __WIN32__ ) || defined( _WIN64 )
#define PATH_SEPARATOR "\\"
#else
#define PATH_SEPARATOR "/"
#endif

static void
_processSegment(const char *zKey, u32 idx, char **item, Array_t *self, Array_t *pNewSegs, bool *bStop)
{
    UNUSED_PARAM(zKey);
    UNUSED_PARAM(idx);
    UNUSED_PARAM(self);
    UNUSED_PARAM(bStop);

    if (*item == NULL || strcmp(*item, ".") == 0)
        return;

    if (strcmp(*item, "..") != 0)
    {
        Array_setNth(pNewSegs, pNewSegs->iCnt, *item);
    }
    else
        if (pNewSegs->iCnt > 0)
            Array_setNth(pNewSegs, pNewSegs->iCnt - 1, NULL);
}

static void
_concatenateSegment(const char *zKey, uint32_t idx, char **item, Array_t *pNewSegs, StringBuilder *sb, bool *bStop)
{
    UNUSED_PARAM(zKey);
    UNUSED_PARAM(idx);
    UNUSED_PARAM(pNewSegs);
    UNUSED_PARAM(bStop);

    if (!*item)
        return;

    StringBuilder_append(sb, PATH_SEPARATOR, 1);

    StringBuilder_append(sb, *item, (int32_t) strlen(*item));
}

void static _splitPath(Array_t *segments, const char *zPath, const char* zSeparator)
{
    char *pSeg = strtok((char *) zPath, zSeparator);
    while (pSeg)
    {
        Array_setNth(segments, segments->iCnt, &pSeg);
        pSeg = strtok(NULL, zSeparator);
    }
}

void Path_join(char **pzResult, const char *zBase, const char *zAddPath)
{
    assert(pzResult);

    // Split path parameters by '/'
    Array_t segments;
    Array_init(&segments, sizeof(char *), sqlite3_free);

    _splitPath(&segments, zBase, PATH_SEPARATOR);
    _splitPath(&segments, zAddPath, "/");

    Array_t newSegs;
    Array_init(&newSegs, sizeof(char *), NULL);

    StringBuilder strBuf;
    StringBuilder_init(&strBuf);

    if (segments.iCnt > 0 && strcmp(*(char **) (Array_getNth(&segments, 0)), "") == 0)
        StringBuilder_append(&strBuf, PATH_SEPARATOR, 1);

    Array_each(&segments, (void *) _processSegment, &newSegs);

    Array_each(&newSegs, (void *) _concatenateSegment, &strBuf);

    *pzResult = strBuf.zBuf;

    // to prevent memory deallocation
    strBuf.bStatic = true;

    Array_clear(&segments);
    Array_clear(&newSegs);
    StringBuilder_clear(&strBuf);
}

void Path_dirname(char **pzResult, const char *zPath)
{
    Path_join(pzResult, zPath, "..");
}

#undef PATH_SEPARATOR
