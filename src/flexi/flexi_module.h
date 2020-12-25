//
// Created by slanska on 2017-02-16.
//

#ifndef FLEXI_MODULE_H
#define FLEXI_MODULE_H

#ifdef __cplusplus
extern "C" {
#endif

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <sqlite3ext.h>
#include "../util/hash.h"
#include "../util/Array.h"
#include "../util/rbtree.h"

/*
 * DB and Lua context for Flexilite.
 * Entry point to all Lua calls
 */
typedef struct FlexiliteContext_t
{
    // sqlite3 database handler
    sqlite3 *db;

    // Lua state associated with sqlite3 connection
    lua_State *L;

    // Lua registry index to access DBContext
    int DBContext_Index;

    // Lua registry index to access lua-sqlite connection
    int SQLiteConn_Index;
} FlexiliteContext_t;

int flexi_init(sqlite3 *db,
               char **pzErrMsg,
               const sqlite3_api_routines *pApi,
               FlexiliteContext_t** pDBCtx);

void flexi_free(FlexiliteContext_t* pCtx);

int register_flexi_rel_vtable(sqlite3* db, FlexiliteContext_t* pCtx);
//int register_flexi_data_vtable(sqlite3* db, FlexiliteContext_t* pCtx);

#ifdef __cplusplus
}
#endif

#endif //FLEXI_MODULE_H
