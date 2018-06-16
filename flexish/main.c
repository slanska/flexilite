//
// Created by slanska on 2017-12-07.
//

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdlib.h>

/*
 * Init Lua context. Load index.lua
 */
int main()
{
    int exit_code = 0;
    lua_State *L = luaL_newstate();
    if (!L)
    {
        fprintf(stderr, "Could not initialize Lua\n");
        return 1;
    }
    luaL_openlibs(L); /* Open standard libraries */

    // TODO Pass arguments

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

