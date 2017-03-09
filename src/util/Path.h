//
// Created by slanska on 2017-03-07.
//

#ifndef FLEXILITE_PATH_H
#define FLEXILITE_PATH_H

#ifdef SQLITE_CORE

#include <sqlite3.h>

#else

#include <sqlite3ext.h>

SQLITE_EXTENSION_INIT3

#endif


/*
 * Path.join implementation, inspired by Node.js and ported from JavaScript code
 * zBase path should use OS specific separator ('/' or '\\')
 * zAddPath should always use '/'
 * Result is returned in *pzResult, as OS specific path
 */
void Path_join(char **pzResult, const char *zBase, const char *zAddPath);

void Path_dirname(char **pzResult, const char *zPath);

#endif //FLEXILITE_PATH_H
