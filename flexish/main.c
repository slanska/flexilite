//
// Created by slanska on 2017-12-07.
//

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdlib.h>

#include "../lib/lua-base64/lbase64.c"
//#include "../lib/lua-sqlite/lsqlite3.c"

/* check that argument has no extra characters at the end */
#define notail(x)    {if ((x)[2] != '\0') return -1;}

#define FLAGS_INTERACTIVE    1
#define FLAGS_VERSION        2
#define FLAGS_EXEC        4
#define FLAGS_OPTION        8
#define FLAGS_NOENV        16

// Source: lib/luajit-2.1/src/luajit.c
static int collectargs(char **argv, int *flags)
{
    int i;
    for (i = 1; argv[i] != NULL; i++)
    {
        if (argv[i][0] != '-')  /* Not an option? */
            return i;
        switch (argv[i][1])
        {  /* Check option. */
            case '-':
            notail(argv[i]);
                return i + 1;
            case '\0':
                return i;
            case 'i':
            notail(argv[i]);
                *flags |= FLAGS_INTERACTIVE;
                /* fallthrough */
            case 'v':
            notail(argv[i]);
                *flags |= FLAGS_VERSION;
                break;
            case 'e':
                *flags |= FLAGS_EXEC;
            case 'j':  /* LuaJIT extension */
            case 'l':
                *flags |= FLAGS_OPTION;
                if (argv[i][2] == '\0')
                {
                    i++;
                    if (argv[i] == NULL) return -1;
                }
                break;
            case 'O':
                break;  /* LuaJIT extension */
            case 'b':  /* LuaJIT extension */
                if (*flags) return -1;
                *flags |= FLAGS_EXEC;
                return i + 1;
            case 'E':
                *flags |= FLAGS_NOENV;
                break;
            default:
                return -1;  /* invalid option */
        }
    }
    return i;
}


// Sets global variable
static void createargtable(lua_State *L, char **argv, int argc, int argf)
{
    int i;
    lua_createtable(L, argc - argf, argf);
    for (i = 0; i < argc; i++)
    {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i + 1);
//        lua_rawseti(L, -2, i - argf);
    }
    lua_setglobal(L, "arg");
}

/*
 * Init Lua context. Load index.lua
 */
int main(int argc, char *argv[])
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
    luaopen_base64(L);
    luaopen_lsqlite3(L);

    // Pass app arguments to Lua
    int argn;
    int flags = 0;
//    if (argv[0] && argv[0][0]) progname = argv[0];

//    argn = collectargs(argv, &flags);
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

