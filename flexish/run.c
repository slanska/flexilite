//
// Created by slanska on 2018-06-17.
//

//
// Created by slanska on 2017-12-07.
//

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdlib.h>

// Sets global variable
static void createargtable(lua_State *L, char **argv, int argc, int argf)
{
    int i;
    lua_createtable(L, argc - argf, argf);
    for (i = 0; i < argc; i++)
    {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setglobal(L, "arg");
}

int luaopen_base64(lua_State *L);

int luaopen_lsqlite3(lua_State *L);

int luaopen_cjson(lua_State *l);

int luaopen_lfs (lua_State *L) ;

/*
 * Init Lua context. Load index.lua
 */
int RunFlexish(int argc, char *argv[])
{
    int exit_code = 0;
    lua_State *L = luaL_newstate();
    if (!L)
    {
        fprintf(stderr, "Could not initialize Lua\n");
        return 1;
    }

    /* Stop collector during library initialization. */
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

    // Pass app arguments to Lua
    createargtable(L, &argv[1], argc - 1, argc - 1);

    /* Load the file containing the script we are going to run */
    int status = luaL_loadstring(L, "require('index')");
    if (status)
    {
        /* If something went wrong, error message is at the top of */
        /* the stack */
        fprintf(stderr, "Couldn't load string: %s\n", lua_tostring(L, -1));
        exit_code = 1;
        goto __EXIT__;
    }

    status = lua_pcall(L, 0, LUA_MULTRET, 0);
    if (status)
    {
        fprintf(stderr, "Couldn't execute Lua: %s\n", lua_tostring(L, -1));
        exit_code = 1;
        goto __EXIT__;
    }

    __EXIT__:
    lua_close(L);
    exit(exit_code);
}



