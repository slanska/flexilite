//
// Created by slanska on 2017-02-16.
//

#ifndef FLEXILITE_FLEXI_ENV_H
#define FLEXILITE_FLEXI_ENV_H

#include <sqlite3ext.h>
#include <duktape.h>
#include "../util/hash.h"
#include "flexi_UserInfo_t.h"
#include "../util/Array.h"

SQLITE_EXTENSION_INIT3

/*
 * Forward declaration
 */

typedef struct flexi_ClassDef_t flexi_ClassDef_t;

/*
 * SQLite statements used for flexi management
 *
 */

enum FLEXI_CTX_STMT
{
    // Delete .objects
            STMT_DEL_OBJ = 0,

    // Update .objects
            STMT_UPD_OBJ = 1,

    // Update .ref-values
            STMT_UPD_PROP = 2,

    // Insert into .objects
            STMT_INS_OBJ = 3,

    // Insert into .ref-values
            STMT_INS_PROP = 4,

    // Delete from .ref-values
            STMT_DEL_PROP = 5,

    // Update .object ID ?? TODO
            STMT_UPD_OBJ_ID = 6,

    // Insert into .names_props
            STMT_INS_NAME = 7,

    // Select from .classes by name TODO Used?
            STMT_SEL_CLS_BY_NAME = 8,

    // Select from .names_props by ID
            STMT_SEL_NAME_ID = 9,

    // Select property by property ID
            STMT_SEL_PROP_ID = 10,

    // Insert into .range_data
            STMT_INS_RTREE = 11,

    // Update .range_data
            STMT_UPD_RTREE = 12,

    // Delete from .range_data
            STMT_DEL_RTREE = 13,

    // Load .classes definition TODO Used?
            STMT_LOAD_CLS = 14,

    // Load flexi_props TODO Used
            STMT_LOAD_CLS_PROP = 15,

    // Get class ID by its name
            STMT_CLS_ID_BY_NAME = 16,

    // Insert into .classes
            STMT_INS_CLS = 17,

    // TODO Check if class has data (objects)
            STMT_CLS_HAS_DATA = 18,

    // Parse property JSON definition
            STMT_PROP_PARSE = 19,

    // Rename class
            STMT_CLS_RENAME = 20,

    // Updates .classes
            STMT_UPDATE_CLS_DEF = 21,

    // Get property ID by its name
            STMT_SEL_PROP_ID_BY_NAME = 22,

    // Get current user version
            STMT_USER_VERSION_GET = 24,

    // Get name text value by its ID
            STMT_GET_NAME_BY_ID = 25,

    // Load from .objects by object ID
            STMT_SEL_OBJ = 26,

    // Load from .ref-values by object ID
            STMT_SEL_REF_VALUES = 27,

    // Should be last one in the list
            STMT_DEL_FTS = 30
};

/*
 * Modes for the content of Data column in result of select Data from flexi_data ....
 */
enum FLEXI_DATA_LOAD_ROW_MODES
{
    LOAD_ROW_MODE_ROW_PER_OBJECT = 0,
    LOAD_ROW_MODE_SINGLE_JSON = 1,
    LOAD_ROW_MODE_JSON_ARRAY = 2,
    LOAD_ROW_MODE_JSON_OBJECT = 3,
    LOAD_ROW_MODE_EMBED_NESTED = 4,
    LOAD_ROW_MODE_EMBED_REFS = 5
};

/*
 * Connection wide data and settings
 */
typedef struct flexi_Context_t
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
    flexi_UserInfo_t *pCurrentUser;

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

    /*
     * Last error
     */
    char *zLastErrorMessage;
    int iLastErrorCode;

    sqlite3_int64 lUserVersion;

    /*
     * Number of open vtables.
     */
    sqlite3_int64 nRefCount;

    enum FLEXI_DATA_LOAD_ROW_MODES eLoadRowMode;
} flexi_Context_t;

struct flexi_Context_t *flexi_Context_new(sqlite3 *db);

void flexi_Context_free(struct flexi_Context_t *data);

/*
 * Finds class by its name. Returns found ID in pClassID. If class not found, sets pClassID to -1;
 * Returns SQLITE_OK if operation was executed successfully, or SQLITE error code
 */
int flexi_Context_getClassIdByName(struct flexi_Context_t *pCtx,
                                   const char *zClassName, sqlite3_int64 *pClassID);

/*
 * Ensures that there is given Name in [.names_props] table.
 * Returns name id in pNameID (if not null)
 */
int flexi_Context_getNameId(struct flexi_Context_t *pCtx,
                            const char *zName, sqlite3_int64 *pNameID);

/*
 * Finds property ID by its class ID and name ID
 */
int flexi_Context_getPropIdByClassAndNameIds
        (struct flexi_Context_t *pCtx,
         sqlite3_int64 lClassID, sqlite3_int64 lPropNameID,
         sqlite3_int64 *plPropID);

/*
 * Ensures that there is given Name in [.names_props] table.
 * Returns name id in pNameID (if not null)
 */
int flexi_Context_insertName(struct flexi_Context_t *pCtx, const char *zName,
                             sqlite3_int64 *pNameID);

/*
 * Adds or replaces class definition. If another class definition with the same name existed, disposes it
 */
int flexi_Context_addClassDef(struct flexi_Context_t *self, flexi_ClassDef_t *pClassDef);

int flexi_Context_getClassByName(struct flexi_Context_t *self, const char *zClassName, flexi_ClassDef_t **ppClassDef);

int flexi_Context_getClassById(struct flexi_Context_t *self, sqlite3_int64 lClassId, flexi_ClassDef_t **ppClassDef);

/*
 * Checks if name does not have invalid characters and its length is within supported range (1-128)
 * Valid identifier should start from _ or letter, following by digits, dashes, underscores and letters
 * @return SQLITE_OK is name is good. Error code, otherwise.
 */
bool db_validate_name(const char *zName);

int getColumnAsText(char **pzDest, sqlite3_stmt *pStmt, int iCol);

char *String_substr(const char *zSource, intptr_t start, intptr_t len);

/*
 * Find property ID by class ID and property name
 * if property is not found, plPropID is set to -1
 * Return SQLite result
 */
int flexi_Context_getPropIdByClassIdAndName(struct flexi_Context_t *pCtx,
                                            sqlite3_int64 lClassID, const char *zPropName,
                                            sqlite3_int64 *plPropID);

/*
 * Returns current user version value in plUserVersion
 * If bIncrement == true, increments user version value
 */
int flexi_Context_userVersion(struct flexi_Context_t *pCtx, sqlite3_int64 *plUserVersion, bool bIncrement);

/*
 * Checks if class definitions and other metadata loaded into context is still valid.
 * Verification is made based on PRAGMA USER_VERSION
 * If changes are detected, loaded classes and other metadata will be reset
 */
int flexi_Context_checkMetaDataCache(struct flexi_Context_t *pCtx);

/*
 * Sets error message and code to context.
 * If zErrorMessage is not NULL, it is expected to be allocated by sqlite3_mprintf or sqlite3_malloc
 * If it is NULL, then sqlite3_errmsg will be used to get error message from database context
 */
void flexi_Context_setError(struct flexi_Context_t *pCtx, int iErrorCode, char *zErrorMessage);

/*
 * Retrieved name text value by its ID. Returns SQLite code (SQLITE_OK if found, SQLITE_NOT_FOUND if name does not exist)
 */
int flexi_Context_getNameValueByID(struct flexi_Context_t *pCtx, sqlite3_int64 lNameID, char **pzName);

/*
 * Ensures that SQLite statement in the context list of predefined statements is initialized/reset
 */
int flexi_Context_stmtInit(struct flexi_Context_t *pCtx, enum FLEXI_CTX_STMT stmt, const char *zSql,
                           sqlite3_stmt **pStmt);

/*
 * flexi('config', name [, value])
 */
void flexi_config_func(sqlite3_context *context,
                       int argc,
                       sqlite3_value **argv);

#endif //FLEXILITE_FLEXI_ENV_H
