//
// Created by slanska on 2017-01-18.
//

// Using linked version of SQLite

//#define SQLITE_CORE

extern "C"
{
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

#include <cstdint>
#include <cstring>
#include <climits>
#include <zconf.h>



#include "definitions.h"

int main(int argc, char **argv)
{
    char *zDir = nullptr;
    Path_dirname(&zDir, *argv);

    // TODO temp - getcwd is not supported by Universal Window Apps
    char zCurrentDir[PATH_MAX + 1];
    getcwd(zCurrentDir, PATH_MAX);

    if (zDir == nullptr || strlen(zDir) == 0 || strcmp(zDir, ".") == 0)
    {
        sqlite3_free(zDir);
        zDir = sqlite3_mprintf("%s", zCurrentDir);
    }
    printf("Current directory: %s, zDir: %s\n", zCurrentDir, zDir);

    lua_State *L = luaL_newstate();
    luaL_openlibs(L);
//    luaopen_lsqlite3(L);
//    luaopen_cjson(L);
    if (luaL_dostring(L, "require('socket')\n"
            "require(\"mobdebug\").loop()"))
    {
        printf("doString: %s\n", lua_tostring(L, -1));
    }
    printf("\nLua string\n");
    lua_pop(L, 1);


    sqlite3 *pDB = nullptr;
    char *zSchemaSql = nullptr;
    char *zError = nullptr;

    //    run_sql_tests(zDir, "../../test/json/sql-test.class.json");
    int result = 0;
    CHECK_CALL(sqlite3_open_v2(":memory:", &pDB,
                               SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_SHAREDCACHE,
                               nullptr));

    CHECK_CALL(sqlite3_enable_load_extension(pDB, 1));

    // load extension library
    CHECK_CALL(sqlite3_load_extension(pDB, "/Users/ruslanskorynin/Documents/Github/slanska/flexilite/bin/libFlexilite", nullptr, &zError));
//    CHECK_CALL(sqlite3_load_extension(pDB, "../../bin/libFlexilite", nullptr, &zError));

    // load and run db schema
//    CHECK_CALL(file_load_utf8("../../sql/dbschema.sql", &zSchemaSql));
//    CHECK_CALL(sqlite3_exec(pDB, (const char *) zSchemaSql, nullptr, nullptr, &zError));

    ONERROR:
    EXIT:
    sqlite3_free(zDir);
    sqlite3_close(pDB);

}

