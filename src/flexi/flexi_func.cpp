//
// Created by slanska on 2017-02-16.
//

/*
 * Implementation of proxy 'flexi' function
 */

extern "C"
{
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

#include <iostream>
#include <fstream>
// TODO #include <zconf.h>

#include "../project_defs.h"
#include "flexi_class.h"
#include "../util/Path.h"

// External declarations
extern "C"
{
LUALIB_API int luaopen_lsqlite3(lua_State *L);
int luaopen_cjson(lua_State *l);
int luaopen_base64(lua_State *L);

int luaopen_lsqlite3(lua_State *L);

int luaopen_cjson(lua_State *l);

int luaopen_cjson_safe(lua_State *l);

int luaopen_lfs(lua_State *L);

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
}

/*
 * Custom memory allocator helper for Lua, based on SQLite memory management API
 * ud - FlexiliteContext_t*
 */
static void *lua_alloc_handler(void *ud, void *ptr, size_t osize, size_t nsize)
{
    if (ptr == nullptr)
    {
        // Allocating new object. osize is a type of new object
        return sqlite3_malloc((int)nsize);
    }

    if (nsize == 0)
    {
        // Delete existing object
        sqlite3_free(ptr);
        return nullptr;
    }

    // Reallocating existing object
    return sqlite3_realloc(ptr, (int)nsize);
}


extern "C"

int flexi_init(sqlite3 *db,
               char **pzErrMsg,
               const sqlite3_api_routines *pApi)
{
//    void(pApi);

    try
    {
        int result;

        auto pCtx = (FlexiliteContext_t *) sqlite3_malloc(sizeof(FlexiliteContext_t));

        pCtx->db = db;
        pCtx->L = lua_newstate(lua_alloc_handler, pCtx);

        if (pCtx->L == nullptr)
        {
            *pzErrMsg = sqlite3_mprintf("Flexilite: cannot initialize LuaJIT");
            result = SQLITE_ERROR;
            goto EXIT;
        }

        lua_gc(pCtx->L, LUA_GCSTOP, 0);
        luaL_openlibs(pCtx->L);
        lua_gc(pCtx->L, LUA_GCRESTART, -1);

        /*
         * Open other Lua modules implemented in C
        */
        luaopen_lfs(pCtx->L);
        luaopen_base64(pCtx->L);
        luaopen_lsqlite3(pCtx->L);
        luaopen_cjson(pCtx->L);
        luaopen_cjson_safe(pCtx->L);

        // Create context, by passing SQLite db connection
        if (luaL_dostring(pCtx->L, "return require 'sqlite3'"))
        {
            *pzErrMsg = sqlite3_mprintf("Flexilite require sqlite3: %s\n", lua_tostring(pCtx->L, -1));
            printf(*pzErrMsg);
            result = SQLITE_ERROR;
            goto EXIT;
        }

        lua_getfield(pCtx->L, -1, "open_ptr");
        lua_pushlightuserdata(pCtx->L, db);
        if (lua_pcall(pCtx->L, 1, 1, 0))
        {
            *pzErrMsg = sqlite3_mprintf("Flexilite sqlite.open_ptr: %s\n", lua_tostring(pCtx->L, -1));
            printf(*pzErrMsg);
            result = SQLITE_ERROR;
            goto EXIT;
        }

        pCtx->SQLiteConn_Index = luaL_ref(pCtx->L, LUA_REGISTRYINDEX);

        // Create context, by passing SQLite db connection
        if (luaL_dostring(pCtx->L, "return require ('DBContext')"))
        {
            *pzErrMsg = sqlite3_mprintf("Flexilite require DBContext: %s\n", lua_tostring(pCtx->L, -1));
            printf(*pzErrMsg);
            result = SQLITE_ERROR;
            goto EXIT;
        }

        lua_rawgeti(pCtx->L, LUA_REGISTRYINDEX, pCtx->SQLiteConn_Index);
        if (lua_pcall(pCtx->L, 1, 1, 0))
        {
            *pzErrMsg = sqlite3_mprintf("Flexilite DBContext(db): %s\n", lua_tostring(pCtx->L, -1));
            printf(*pzErrMsg);
            result = SQLITE_ERROR;
            goto EXIT;
        }
        pCtx->DBContext_Index = luaL_ref(pCtx->L, LUA_REGISTRYINDEX);

        // Remember Lua state and DBContext reference

        result = SQLITE_OK;
        goto EXIT;

        ONERROR:
        // TODO Needed?

        EXIT:
        return result;
    }
    catch (...)
    {
        return SQLITE_ERROR;
    }
}
