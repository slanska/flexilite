//
// Created by slanska on 2017-01-22.
//

/*
 * Project internal definitions
 */


#ifndef SQLITE_EXTENSIONS_PROJECT_DEFS_H
#define SQLITE_EXTENSIONS_PROJECT_DEFS_H

#include "../lib/sqlite/sqlite3ext.h"

SQLITE_EXTENSION_INIT3

#include <assert.h>
#include <string.h>
#include <ctype.h>
#include <alloca.h>
#include <stdio.h>

#include "common/common.h"

/*
 * External resources packed into C files
 */
//#include "./resources/dbschema.res.h"

/*
 * Macro to determine if property has range type
 */
// TODO temporary implementation
#define IS_RANGE_PROPERTY(propType) 0

/*
 * Internal API
 */
//
/////
///// \param db
///// \param zClassName
///// \param zClassDef
///// \param bCreateVTable
///// \param pzError
///// \return
//int flexi_class_create(sqlite3 *db,
//        // User data
//                       void *pAux,
//                       const char *zClassName,
//                       const char *zClassDef,
//                       int bCreateVTable,
//                       char **pzError);
//
#endif //SQLITE_EXTENSIONS_PROJECT_DEFS_H

