//
// Created by slanska on 2017-02-16.
//

#ifndef FLEXILITE_FLEXI_ENV_H
#define FLEXILITE_FLEXI_ENV_H

#include <sqlite3ext.h>
#include <duktape.h>
//#include "flexi_prop.h"
#include "../util/hash.h"
#include "flexi_user_info.h"
#include "../util/buffer.h"

SQLITE_EXTENSION_INIT3

/*
 * SQLite statements used for flexi management
 *
 */

enum FLEXI_CTX_STMT
{
    STMT_DEL_OBJ = 0,
    STMT_UPD_OBJ = 1,
    STMT_UPD_PROP = 2,
    STMT_INS_OBJ = 3,
    STMT_INS_PROP = 4,
    STMT_DEL_PROP = 5,
    STMT_UPD_OBJ_ID = 6,
    STMT_INS_NAME = 7,
    STMT_SEL_CLS_BY_NAME = 8,
    STMT_SEL_NAME_ID = 9,
    STMT_SEL_PROP_ID = 10,
    STMT_INS_RTREE = 11,
    STMT_UPD_RTREE = 12,
    STMT_DEL_RTREE = 13,
    STMT_LOAD_CLS = 14,
    STMT_LOAD_CLS_PROP = 15,
    STMT_CLS_ID_BY_NAME = 16,
    STMT_INS_CLS = 17,
    STMT_CLS_HAS_DATA = 18,
    STMT_PROP_PARSE = 19,
    STMT_CLS_RENAME = 20,

    // Should be last one in the list
            STMT_DEL_FTS = 30
};

/*
 * Connection wide data and settings
 */
struct flexi_db_context
{
    /*
     * Associated database connection
     */
    sqlite3 *db;

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
    flexi_user_info *pCurrentUser;

    /*
     * Duktape context. Created on demand
     */
    duk_context *pDuk;

    /*
     * Hash of loaded class definitions (by current names)
     */
    Hash classDefsByName;

    // TODO Init and use
    Hash classDefsById;
};

struct flexi_db_context *flexi_db_context_new(sqlite3 *db);

void flexi_Context_free(struct flexi_db_context *data);

/*
 * Finds class by its name. Returns found ID in pClassID. If class not found, sets pClassID to -1;
 * Returns SQLITE_OK if operation was executed successfully, or SQLITE error code
 */
int flexi_Context_getClassIdByName(struct flexi_db_context *pCtx,
                                   const char *zClassName, sqlite3_int64 *pClassID);

/*
 * Ensures that there is given Name in [.names_props] table.
 * Returns name id in pNameID (if not null)
 */
int flexi_Context_getNameId(struct flexi_db_context *pCtx,
                            const char *zName, sqlite3_int64 *pNameID);

/*
 * Finds property ID by its class ID and name ID
 */
int flexi_Context_getPropIdByClassAndNameIds
        (struct flexi_db_context *pCtx,
         sqlite3_int64 lClassID, sqlite3_int64 lPropNameID,
         sqlite3_int64 *plPropID);

/*
 * Ensures that there is given Name in [.names_props] table.
 * Returns name id in pNameID (if not null)
 */
int flexi_Context_insertName(struct flexi_db_context *pCtx, const char *zName,
                             sqlite3_int64 *pNameID);

/*
 * Checks if name does not have invalid characters and its length is within supported range (1-128)
 * Valid identifier should start from _ or letter, following by digits, dashes, underscores and letters
 * @return SQLITE_OK is name is good. Error code, otherwise.
 */
bool db_validate_name(const char *zName);

#endif //FLEXILITE_FLEXI_ENV_H
