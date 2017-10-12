//
// Created by slanska on 2017-10-11.
//

#ifndef FLEXILITE_DBCONTEXT_H
#define FLEXILITE_DBCONTEXT_H

#include <string>
#include <map>
#include "../project_defs.h"
#include "ClassDef.h"
#include "../sqlite/Database.h"

struct DBContext
{
    SQLite::Database *database = nullptr;

public:
    explicit DBContext(sqlite3 *_db) : db(_db)
    {}

    /*
   * Associated database connection
   */
    sqlite3 *db;

    sqlite3_stmt *pStmts[STMT_DEL_FTS + 1] = {};

    /*
     * In-memory database used for certain operations, e.g. MATCH function on non-FTS indexed columns.
     * Lazy-opened and initialized on demand, on first attempt to use it.
     */
    sqlite3 *pMemDB = nullptr;

    /*
     * Prepared SQL statement used by MATCH function on non-FTS indexed columns to insert temporary rows
     * into full text index table
     */
    sqlite3_stmt *pMatchFuncInsStmt = nullptr;

    /*
     * Prepared SQL statement used by MATCH function on non-FTS indexed columns to select temporary rows
     * from full text index table
     */
    sqlite3_stmt *pMatchFuncSelStmt = nullptr;

    /*
     * Info on current user
     */
    flexi_UserInfo_t *pCurrentUser = nullptr;

    /*
     * Duktape context. Created on demand
     */
    duk_context *pDuk = nullptr;

    /*
     * Hash of loaded class definitions (by current names)
     */
    //    Hash classDefsByName;

    std::map<std::string, ClassDef> classDefsByName = {};

    // TODO Init and use
    Hash classDefsById = {};

    /*
     * Last error
     */
    char *zLastErrorMessage = nullptr;
    int iLastErrorCode = 0;

    sqlite3_int64 lUserVersion = 0;

    /*
     * Number of open vtables.
     */
    sqlite3_int64 nRefCount = 0;

    enum FLEXI_DATA_LOAD_ROW_MODES eLoadRowMode = LOAD_ROW_MODE_ROW_PER_OBJECT;

    /*
     * RB tree of existing ref-values rows processed during current request (flexi and flexi_data calls)
     * Tree is ordered by objectID, propertyID, property index
     * Items in tree are flexi_RefValue_t
     * Cache gets cleared on every exit
     */
    struct RBTree refValueCache = {};
};

#endif //FLEXILITE_DBCONTEXT_H
