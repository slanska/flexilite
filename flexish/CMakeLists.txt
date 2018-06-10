
cmake_minimum_required(VERSION 2.8)

enable_testing()

if (WIN32)
    add_definitions(-D_CRT_SECURE_NO_WARNINGS)
endif ()

set(CMAKE_BINARY_DIR "${CMAKE_CURRENT_SOURCE_DIR}")

set(PLATFORM "${CMAKE_SYSTEM_NAME}")
string(TOUPPER "${PLATFORM}" PLATFORM)

project(Flexilite_shell)

# SQLite and LuaJIT compile flags
add_definitions(-DSQLITE_ENABLE_FTS4
        -DSQLITE_ENABLE_RTREE
        -DSQLITE_ENABLE_LOAD_EXTENSION
        -DSQLITE_ENABLE_JSON1
        -DLUAJIT_ENABLE_LUA52COMPAT)

message("Building on: ${CMAKE_SYSTEM_NAME}")

include_directories(
        ../lib/sqlite
        ../lib/luajit-2.1/src
)

# Include .lua and .C sources

# Variable to store compiled Lua files
set(oLuaFiles)

# TODO
#add_custom_target(Generate_Resources
#        ALL
#        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
#        COMMAND xxd -i sql/dbschema.sql > src/resources/dbschema.res.h
#        COMMENT "Generating resource file for SQL schema."
#        DEPENDS sql/dbschema.sql)
#
#set_source_files_properties(src/resources/dbschema.res.h PROPERTIES GENERATED TRUE)
#add_definitions(-DRESOURCES_GENERATED
#        )

set(LUA_FILES
        # src_lua/
        classCreate.lua
        dumpDatabase.lua
        getStat.lua
        index.lua
        initDb.lua
        runQuery.lua
        sqliteSchemaParser.lua

        #pretty c json
        ../lib/lua-prettycjson/lib/resty/prettycjson.lua

        #penlight
        ../lib/lua-penlight/lua/pl/Date.lua
        ../lib/lua-penlight/lua/pl/Set.lua
        ../lib/lua-penlight/lua/pl/comprehension.lua
        ../lib/lua-penlight/lua/pl/func.lua
        ../lib/lua-penlight/lua/pl/lexer.lua
        ../lib/lua-penlight/lua/pl/pretty.lua
        ../lib/lua-penlight/lua/pl/stringx.lua
        ../lib/lua-penlight/lua/pl/types.lua
        ../lib/lua-penlight/lua/pl/List.lua
        ../lib/lua-penlight/lua/pl/app.lua
        ../lib/lua-penlight/lua/pl/config.lua
        ../lib/lua-penlight/lua/pl/import_into.lua
        ../lib/lua-penlight/lua/pl/luabalanced.lua
        ../lib/lua-penlight/lua/pl/seq.lua
        ../lib/lua-penlight/lua/pl/tablex.lua
        ../lib/lua-penlight/lua/pl/url.lua
        ../lib/lua-penlight/lua/pl/Map.lua
        ../lib/lua-penlight/lua/pl/array2d.lua
        ../lib/lua-penlight/lua/pl/data.lua
        ../lib/lua-penlight/lua/pl/init.lua
        ../lib/lua-penlight/lua/pl/operator.lua
        ../lib/lua-penlight/lua/pl/sip.lua
        ../lib/lua-penlight/lua/pl/template.lua
        ../lib/lua-penlight/lua/pl/utils.lua
        ../lib/lua-penlight/lua/pl/MultiMap.lua
        ../lib/lua-penlight/lua/pl/class.lua
        ../lib/lua-penlight/lua/pl/dir.lua
        ../lib/lua-penlight/lua/pl/input.lua
        ../lib/lua-penlight/lua/pl/path.lua
        ../lib/lua-penlight/lua/pl/strict.lua
        ../lib/lua-penlight/lua/pl/test.lua
        ../lib/lua-penlight/lua/pl/xml.lua
        ../lib/lua-penlight/lua/pl/OrderedMap.lua
        ../lib/lua-penlight/lua/pl/compat.lua
        ../lib/lua-penlight/lua/pl/file.lua
        ../lib/lua-penlight/lua/pl/lapp.lua
        ../lib/lua-penlight/lua/pl/permute.lua
        ../lib/lua-penlight/lua/pl/stringio.lua
        ../lib/lua-penlight/lua/pl/text.lua
        )

#function(PROCESS_LUA_FILE, LuaFile)
#    get_filename_component(LuaFile)
#    if ()
#
#    endif ()
#endfunction(PROCESS_LUA_FILE)

add_subdirectory(../lib/luajit-2.1 ../bin)

target_link_libraries(flexish PUBLIC luajit-static)

# sqlite
# luajit
# lua-cjson
# luasqlite3complete
# base64
# penlight
set(SRC_FILES
        main.c
        ../lib/sqlite/sqlite3.c
        ../src/lua-sqlite/lsqlite3.c
        ../lib/lua-cjson/fpconv.c
        ../lib/lua-cjson/lua_cjson.c
        ../lib/lua-cjson/strbuf.c
        ../lib/lua-base64/lbase64.c



        ${oLuaFiles}
        )

#add_subdirectory(../lib/luajit-2.1)

add_executable(flexish ${SRC_FILES})

# Flexish lua sources