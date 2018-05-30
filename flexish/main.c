//
// Created by slanska on 2017-12-07.
//

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

/*
 * Init Lua context. Load index.lua
 */
int main()
{
    lua_State *L = luaL_newstate();
    if (!L)
    {
        // TODO More error info?
        return 1;
    }
    luaL_openlibs(L); /* Open standard libraries */

}

