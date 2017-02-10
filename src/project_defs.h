//
// Created by slanska on 2017-01-22.
//

/*
 * Project internal definitions
 */


//#include "./misc/json1.h"
//#include "./flexi/flexi_eav.h"
//#include "./typings/DBDefinitions.h"
//#include "./util/hash.h"
//#include "./flexi/flexi_eav.h"
//#include "./misc/regexp.h"
//#include "./fts/fts3Int.h"

#ifndef SQLITE_EXTENSIONS_PROJECT_DEFS_H
#define SQLITE_EXTENSIONS_PROJECT_DEFS_H

#include "../lib/sqlite/sqlite3ext.h"

SQLITE_EXTENSION_INIT3

#include <assert.h>
#include <string.h>
#include <ctype.h>
#include <alloca.h>
#include <stdio.h>

/*
 * Utility macros
 * Designed to provide uniformed way to handle result from sqlite API calls.
 * Should be used in the following pattern for function:
 *
 * int result = SQLITE_OK; // int result must be declared
 * ... API calls
 *
 * goto FINALLY; // skip CATCH
 *
 * CATCH:
 * clean up on error
 * return result; // optionally, return error code
 * FINALLY:
 * clean up when done regardless if success or failure
 * return result;
 *
 * result declaration, CATCH and FINALLY must be always present in the function body
 * if one of the following macros is used
 *
 */
#define CHECK_CALL(call)       result = (call); \
        if (result != SQLITE_OK) goto CATCH;
#define CHECK_STMT(call)       result = (call); \
        if (result != SQLITE_DONE && result != SQLITE_ROW) goto CATCH;

#define CHECK_MALLOC(v, s) v = sqlite3_malloc(s); \
        if (v == NULL) { result = SQLITE_NOMEM; goto CATCH;}

/*
 * Macro to determine if property has range type
 */
// TODO temporary implementation
#define IS_RANGE_PROPERTY(propType) 0

/*
 * Internal API
 */

///
/// \param db
/// \param zClassName
/// \param zClassDef
/// \param bCreateVTable
/// \param pzError
/// \return
int flexi_class_create(sqlite3 *db,
        // User data
                       void *pAux,
                       const char *zClassName,
                       const char *zClassDef,
                       int bCreateVTable,
                       char **pzError);

#endif //SQLITE_EXTENSIONS_PROJECT_DEFS_H

