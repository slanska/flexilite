//
// Created by slanska on 2017-03-07.
//

#include <string.h>
#include "Path.h"
#include "buffer.h"
#include "StringBuilder.h"

/*
 * https://gist.github.com/creationix/7435851
 *
 * Joins path segments.  Preserves initial "/" and resolves ".." and "."
// Does not support using ".." to go above/outside the root.
// This means that join("foo", "../../bar") will not resolve to "../bar"
function join() {
    // Split the inputs into a list of path commands.
    var parts = [];
    for (var i = 0, l = arguments.length; i < l; i++) {
        parts = parts.concat(arguments[i].split("/"));
    }
    // Interpret the path commands to get the new resolved path.
    var newParts = [];
    for (i = 0, l = parts.length; i < l; i++) {
        var part = parts[i];
        // Remove leading and trailing slashes
        // Also remove "." segments
        if (!part || part === ".") continue;
        // Interpret ".." to pop the last segment
        if (part === "..") newParts.pop();
            // Push new path segments.
        else newParts.push(part);
    }
    // Preserve the initial slash if there was one.
    if (parts[0] === "") newParts.unshift("");
    // Turn back into a single string path.
    return newParts.join("/") || (newParts.length ? "/" : ".");
}


// A simple function to get the dirname of a path
// Trailing slashes are ignored. Leading slash is preserved.
function dirname(path) {
    return join(path, "..");
}
 */

static void
_processSegment(const char *zKey, int idx, var item, Buffer *self, Buffer *pNewSegs, bool *bStop)
{

}

static void
_concatenateSegment(const char *zKey, int idx, var item, Buffer *self, Buffer *pNewSegs, bool *bStop)
{

}

void Path_join(char **pzResult, const char *zBase, const char *zAppendix)
{
    // Keep pointers to segments here
    Buffer segments;
    Buffer_init(&segments, sizeof(char *), NULL);

    Buffer newSegs;
    Buffer_init(&newSegs, sizeof(char *), NULL);

    char *pSeg = strtok(zBase, "/");
    while (pSeg)
    {
        Buffer_set(&segments, segments.iCnt, &pSeg);
        pSeg = strtok(NULL, "/");
    }

    StringBuilder strBuf;
    StringBuilder_init(&strBuf);

    Buffer_each(&segments, (void *) _processSegment, &newSegs);

    Buffer_each(&newSegs, (void *) _concatenateSegment, NULL);

    *pzResult = strBuf.zBuf;
    // to prevent memory deallocation
    strBuf.bStatic = true;

    FINALLY:
    Buffer_clear(&segments);
    Buffer_clear(&newSegs);
    StringBuilder_clear(&strBuf);
}
