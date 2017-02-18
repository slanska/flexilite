//
// Created by slanska on 2017-02-16.
//

#ifndef FLEXILITE_FLEXI_ENV_H
#define FLEXILITE_FLEXI_ENV_H

#include <sqlite3ext.h>
#include "../../lib/duktape/duktape.h"

SQLITE_EXTENSION_INIT3

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
 * Container for user ID and roles
 */
struct flexi_user_info {
    /*
     * User ID
     */
    char *zUserID;

    /*
     * List of roles
     */
    char **zRoles;

    /*
     * Number of roles
     */
    int nRoles;

    /*
     * Current culture
     */
    char *zCulture;
};

void flexi_free_user_info(struct flexi_user_info *p);

/*
 * Handle for opened flexilite virtual table
 */
struct flexi_vtab {
    sqlite3_vtab base;
    sqlite3 *db;
    sqlite3_int64 iClassID;

    /*
     * Number of columns, i.e. items in property and column arrays
     */
    int nCols;

    /*
     * Actual length of pProps array (>= nCols)
     */
    int nPropColsAllocated;

    // Sorted array of mapping between property ID and column index
    //struct flexi_prop_col_map *pSortedProps;

    // Array of property metadata, by column index
    struct flexi_prop_metadata *pProps;

    char *zHash;
    sqlite3_int64 iNameID;
    short int bSystemClass;
    int xCtloMask;
    struct flexi_db_context *pDBEnv;
};

/*
 * Connection wide data and settings
 */
struct flexi_db_context {

    /*
     * Associated database connection
     */
    sqlite3 *db;

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

    /*
     * Info on current user
     */
    struct flexi_user_info *pCurrentUser;

    /*
     * Duktape context. Created on demand
     */
    duk_context *pDuk;

    // TODO Opened classes
};

void flexi_db_context_deinit(struct flexi_db_context *pDBEnv);

void flexi_vtab_free(struct flexi_vtab *vtab);

/*
 * Ensures that there is given Name in [.names_props] table.
 * Returns name id in pNameID (if not null)
 */
int db_get_name_id(struct flexi_db_context *pDBEnv,
                   const char *zName, sqlite3_int64 *pNameID);

/*
 * Finds property ID by its class ID and name ID
 */
int db_get_prop_id_by_class_and_name
        (struct flexi_db_context *pDBEnv,
         sqlite3_int64 lClassID, sqlite3_int64 lPropNameID,
         sqlite3_int64 *plPropID);

/*
 * Ensures that there is given Name in [.names_props] table.
 * Returns name id in pNameID (if not null)
 */
int db_insert_name(struct flexi_db_context *pDBEnv, const char *zName,
                   sqlite3_int64 *pNameID);

#endif //FLEXILITE_FLEXI_ENV_H
