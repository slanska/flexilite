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
 */

void Path_join(char **pzResult, const char *zBase, const char *zAppendix);

#endif //FLEXILITE_PATH_H
