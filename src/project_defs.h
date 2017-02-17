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

#include "flexi/flexi_class.h"

/*
 * Macro to determine if property has range type
 */
// TODO temporary implementation
#define IS_RANGE_PROPERTY(propType) 0

/*
 * SQLite statements used for flexi management
 *
 */
#define STMT_DEL_OBJ            0
#define STMT_UPD_OBJ            1
#define STMT_UPD_PROP           2
#define STMT_INS_OBJ            3
#define STMT_INS_PROP           4
#define STMT_DEL_PROP           5
#define STMT_UPD_OBJ_ID         6
#define STMT_INS_NAME           7
#define STMT_SEL_CLS_BY_NAME    8
#define STMT_SEL_NAME_ID        9
#define STMT_SEL_PROP_ID        10
#define STMT_INS_RTREE          11
#define STMT_UPD_RTREE          12
#define STMT_DEL_RTREE          13
#define STMT_LOAD_CLS           14
#define STMT_LOAD_CLS_PROP      15

// Should be last one in the list
#define STMT_DEL_FTS            20

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
 * Connection wide data and settings
 */
struct flexi_db_env {
    int nRefCount;
    sqlite3_stmt *pStmts[STMT_DEL_FTS + 1];

    /*
     * In-memory database used for certain operations, e.g. MATCH function on non-FTS indexed columns.
     * Lazy-opened and initialized on demand, on first attempt to use it.
     */
    sqlite3 *pMemDB;

    /*
     * Prepared SQL statement used by MATCH function on non-FTS indexed columns to insert temporary rows
     * into full text index table
     */
    sqlite3_stmt *pMatchFuncInsStmt;

    /*
     * Prepared SQL statement used by MATCH function on non-FTS indexed columns to select temporary rows
     * from full text index table
     */
    sqlite3_stmt *pMatchFuncSelStmt;
};

/*
 * Ensures that there is given Name in [.names] table.
 * Returns name id in pNameID (if not null)
 */
int db_insert_name(struct flexi_db_env *pDBEnv, const char *zName, sqlite3_int64 *pNameID);

/*
 * Finds property ID by its class ID and name ID
 */
int db_get_prop_id_by_class_and_name
        (struct flexi_db_env *pDBEnv,
         sqlite3_int64 lClassID, sqlite3_int64 lPropNameID, sqlite3_int64 *plPropID);

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

