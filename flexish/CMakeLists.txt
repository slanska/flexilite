
cmake_minimum_required(VERSION 3.0.2 FATAL_ERROR)

enable_testing()

if (WIN32)
    add_definitions(-D_CRT_SECURE_NO_WARNINGS)
endif ()

set(CMAKE_BINARY_DIR "${CMAKE_CURRENT_SOURCE_DIR}")

set(PLATFORM "${CMAKE_SYSTEM_NAME}")
string(TOUPPER "${PLATFORM}" PLATFORM)

project(Flexish_static)

# SQLite and LSQLite compile flags
add_definitions(-DSQLITE_ENABLE_FTS4
        -DSQLITE_ENABLE_RTREE
        -DSQLITE_ENABLE_LOAD_EXTENSION
        -DSQLITE_ENABLE_JSON1
        -DENABLE_CJSON_GLOBAL
        -DLUAJIT_ENABLE_LUA52COMPAT
        )

remove_definitions(
        -DLSQLITE_EXTENSION
        -DSQLITE_EXTENSION
)

message("Building on: ${CMAKE_SYSTEM_NAME}")

include_directories(
        ../lib/sqlite
        ../lib/torch-lua/luajit-2.1/src
        ../lib/luafilesystem/src
)

###
#ADD_CUSTOM_TARGET(
#        Compile_Flexilite_LuaFiles
#        ALL
##        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
#        COMMAND luajit ./util/lua2lib.lua ./src_lua/filelist.lua -n libFlexiliteLua.a --output ./obj_lua
#        COMMENT "Compiling Flexilite Lua files"
#)
###

ADD_CUSTOM_TARGET(
        Compile_Flexish_LuaFiles
        ALL
#        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMAND luajit ../util/lua2lib.lua ./filelist.lua -n libFlexishLua.a --output ../obj_lua
        COMMENT "Compiling Flexish Lua files"
)

set(SRC_FILES
        ../lib/lua-sqlite/sqlite3.c
        ../lib/lua-sqlite/lsqlite3.c
        ../lib/lua-cjson/fpconv.c
        ../lib/lua-cjson/lua_cjson.c
        ../lib/lua-cjson/strbuf.c
        ../lib/lua-base64/lbase64.c
        ../lib/luafilesystem/src/lfs.c
        run.c
        )

add_library(FlexishStatic STATIC ${SRC_FILES})
