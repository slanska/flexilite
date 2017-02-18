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

#include "typings/DBDefinitions.h"

#include "flexi/flexi_db_ctx.h"

/*
 * Macro to determine if property has range type
 */
// TODO temporary implementation
#define IS_RANGE_PROPERTY(propType) 0

/*
 * Internally used structures, sub-classed from SQLite structs
 */

struct flexi_prop_metadata {
    sqlite3_int64 iPropID;
    sqlite3_int64 iNameID;
    struct ReCompiled *pRegexCompiled;
    int type;
    char *regex;
    double maxValue;
    double minValue;
    int maxLength;
    int minOccurences;
    int maxOccurences;
    sqlite3_value *defaultValue;
    char *zName;
    short int xRole;
    char bIndexed;
    char bUnique;
    char bFullTextIndex;
    int xCtlv;

    /*
     * 1-10: column is mapped to .range_data columns (1 = A0, 2 = A1, 3 = B0 and so on)
     * 0: not mapped
     */
    unsigned char cRangeColumn;

    /*
     * if not 0x00, mapped to a fixed column in [.objects] table (A-P)
     */
    unsigned char cColMapped;

    /*
     * 0 - no range column
     * 1 - low range bound
     * 2 - high range bound
     */
    unsigned char cRngBound;
};

/*
 * Loads class definition from [.classes] and [.class_properties] tables
 * into ppVTab (casted to flexi_vtab).
 * Used by Create and Connect methods
 */
int flexi_load_class_def(
        sqlite3 *db,
        // User data
        void *pAux,
        const char *zClassName,
        sqlite3_vtab **ppVTab,
        char **pzErr);

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

