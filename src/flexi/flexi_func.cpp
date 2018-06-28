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
#include <zconf.h>

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
}

static int flexi_help_func(sqlite3_context *context,
                           int argc,
                           sqlite3_value **argv)
{
    (void) argc;
    (void) argv;

    const char *zHelp = "Usage:"
                        "   select flexi(<command>, <arguments>...)"
                        "Commands: Arguments:"
                        "   create class: class_name TEXT, class_definition JSON1, as_table BOOL"
                        "   alter class: class_name TEXT, class_definition JSON1, as_table BOOL"
                        "   drop class: class_name TEXT"
                        "   rename class: old_class_name TEXT, new_class_name TEXT"
                        "   create property: class_name TEXT, property_name TEXT, definition JSON1"
                        "   alter property: class_name TEXT, property_name TEXT, definition JSON1"
                        "   drop property: class_name TEXT, property_name TEXT"
                        "   rename property: old_property_name TEXT, new_property_name TEXT"
                        "   init";

    sqlite3_result_text(context, zHelp, -1, NULL);
    return SQLITE_OK;
}

static int flexi_init_func(sqlite3_context *context,
                           int argc,
                           sqlite3_value **argv)
{
    (void) argc;
    (void) argv;

#ifdef RESOURCES_GENERATED

#include "../resources/dbschema.res.h"

    char *zSQL = static_cast<char *>( sqlite3_malloc(sql_dbschema_sql_len + 1));
    memcpy(zSQL, sql_dbschema_sql, sql_dbschema_sql_len);
    zSQL[sql_dbschema_sql_len] = 0;
    sqlite3 *db = sqlite3_context_db_handle(context);
    char *zError = NULL;
    int result;
    CHECK_SQLITE(db, sqlite3_exec(db, zSQL, NULL, NULL, &zError));
    goto EXIT;

    ONERROR:
    sqlite3_result_error(context, zError, -1);

    EXIT:
    sqlite3_free(zSQL);
    return result;

#endif

}

extern "C" int flexi_init(sqlite3 *db,
                          char **pzErrMsg,
                          const sqlite3_api_routines *pApi)
{
    try
    {
        int result;
        sqlite3_stmt *pDummy = nullptr;

        lua_State *L = luaL_newstate();

        lua_gc(L, LUA_GCSTOP, 0);
        luaL_openlibs(L);
        lua_gc(L, LUA_GCRESTART, -1);

        /*
         * Open other Lua modules implemented in C
        */
        luaopen_lfs(L);
        luaopen_base64(L);
        luaopen_lsqlite3(L);
        luaopen_cjson(L);
        luaopen_cjson_safe(L);

        lua_pushlightuserdata(L, db);
        int db_reg_index = luaL_ref(L, LUA_REGISTRYINDEX);

        // TODO temp
        printf("db_reg_index: %d\n", db_reg_index);

        // loadString ("local Flexi = require 'index'; return Flexi")
        // loadString ("local DBContext = require 'DBContext'; return DBContext")
        // Result - function
        // Push db
        // xpcall

        // Create context, by passing SQLite db connection
        if (luaL_dostring(L, "local DBContext = require ('DBContext')"))
        {
            printf("Flexilite initialization: %s\n", lua_tostring(L, -1));
        }
        lua_pop(L, 1);

        result = SQLITE_OK;
        goto EXIT;

        ONERROR:
        // TODO Needed?

        EXIT:
        sqlite3_finalize(pDummy);
        return result;
    }
    catch (...)
    {
        return SQLITE_ERROR;
    }
}
