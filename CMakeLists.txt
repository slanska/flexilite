# This CMAKE builds the following output files:
# EXE sqlite_shell
# EXE flexish - flexish/main.c + libFlexish + luajit-static
# LIB Flexilite - libFlexilite.dylib/so/dll : libFlexilite-static + luajit
# EXE flexi_test - libFlexiliteTest-static

cmake_minimum_required(VERSION 3.0.2 FATAL_ERROR)

enable_testing()

if (WIN32)
    add_definitions(-D_CRT_SECURE_NO_WARNINGS)
endif ()

set(CMAKE_BINARY_DIR "${CMAKE_CURRENT_SOURCE_DIR}")

set(PLATFORM "${CMAKE_SYSTEM_NAME}")
string(TOUPPER "${PLATFORM}" PLATFORM)

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

###############################################################################
# sqlite_shell executable
project(sqlite_shell)

message("Building on: ${CMAKE_SYSTEM_NAME}")

find_package(Threads REQUIRED)

set(SHELL_FILES
        lib/sqlite/shell.c
        lib/sqlite/sqlite3.c
        )

add_executable(sqlite_shell ${SHELL_FILES})

if (WIN32)
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /MT")
    set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /MTd")
    set(CMAKE_C_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /MT")
    set(CMAKE_C_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /MTd")
endif ()

target_compile_definitions(
        sqlite_shell
        PRIVATE
        -DSQLITE_ENABLE_FTS4
        -DSQLITE_ENABLE_RTREE
        -DSQLITE_ENABLE_LOAD_EXTENSION
        -DSQLITE_ENABLE_JSON1
        -DLUAJIT_ENABLE_LUA52COMPAT
        -DSQLITE_EXTENSION
        -DLSQLITE_EXTENSION
        -DENABLE_CJSON_GLOBAL
        -DLUAJIT_ENABLE_GC64
)

# Note libraries are linked AFTER executable is registered
# also, using 'm' for standard math library
target_link_libraries(sqlite_shell ${CMAKE_THREAD_LIBS_INIT} ${CMAKE_DL_LIBS})
if (WIN32)
elseif ()
    target_link_libraries(sqlite_shell m)
endif ()

###############################################################################
# libFlexilite library
project(Flexilite)

include_directories(
        lib/sqlite
        lib/torch-luajit-rocks/luajit-2.1/src
        src/util
)

# Compile Lua files to a static library
ADD_CUSTOM_TARGET(
        Compile_Flexilite_LuaFiles
        ALL
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMAND luajit tools/lua2lib.lua ./src_lua/filelist.lua -n libFlexiliteLua.a --output ./obj_lua
        COMMENT "Compiling Flexilite Lua files"
)

IF (WIN32)
    message('Windows: Flexilite')
    SET(Flexilite_LuaFiles ${CMAKE_CURRENT_SOURCE_DIR}/obj_lua/libFlexiliteLua/libFlexiliteLua.a)
    SET(LuaJit_static ${CMAKE_CURRENT_SOURCE_DIR}/lib/torch-luajit-rocks/luajit-2.1/src/lua51.lib)
    SET(LuaJit_shared ${CMAKE_CURRENT_SOURCE_DIR}/lib/torch-luajit-rocks/luajit-2.1/src/lua51.dll)
ELSEIF (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    message('OSX: Flexilite')
    SET(Flexilite_LuaFiles -Wl,-all_load ${CMAKE_CURRENT_SOURCE_DIR}/obj_lua/libFlexiliteLua/libFlexiliteLua.a)
    SET(LuaJit_static ${CMAKE_CURRENT_SOURCE_DIR}/lib/torch-luajit-rocks/build/luajit-2.1/libluajit-static.a)
    SET(LuaJit_shared ${CMAKE_CURRENT_SOURCE_DIR}/lib/torch-luajit-rocks/build/luajit-2.1/libluajit.dll)
ELSE ()
    message('Linux: Flexilite')
    SET(Flexilite_LuaFiles -Wl,--whole-archive ${CMAKE_CURRENT_SOURCE_DIR}/obj_lua/libFlexiliteLua/libFlexiliteLua.a -Wl,--no-whole-archive -Wl,-E)
    SET(LuaJit_static ${CMAKE_CURRENT_SOURCE_DIR}/lib/torch-luajit-rocks/build/luajit-2.1/libluajit-static.a -ldl -lm -lpthread)
    SET(LuaJit_shared ${CMAKE_CURRENT_SOURCE_DIR}/lib/torch-luajit-rocks/build/luajit-2.1/libluajit.dll)
ENDIF ()

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(EXT_FILES
        # Lua modules written in C
        lib/lua-sqlite/lsqlite3.c
        lib/lua-cjson/fpconv.c
        lib/lua-cjson/lua_cjson.c
        lib/lua-cjson/strbuf.c
        lib/lua-base64/lbase64.c
        lib/luafilesystem/src/lfs.c

        src/misc/json1.c
        src/project_defs.h
        src/main.cpp

        src/misc/eval.c
        src/misc/fileio.c
        src/misc/regexp.c
        src/misc/totype.c

        src/util/hash.c

        src/misc/hash.c

        src/misc/memstat.c

        src/fts/fts3_expr.c
        src/fts/fts3_tokenizer.c
        src/fts/fts3_hash.c

        src/common/common.h
        src/util/Array.c
        src/util/Array.h
        src/flexi/flexi_module.cpp

        src/util/Path.c
        src/util/Path.h
        src/util/StringBuilder.c
        src/util/StringBuilder.h

        src/flexi/flexi_rel_vtable.cpp
        src/flexi/flexi_module.cpp)

set(CMAKE_FIND_LIBRARY_PREFIXES "")

set(CMAKE_MACOSX_RPATH 1)

add_library(Flexilite SHARED ${EXT_FILES})

target_compile_definitions(
        Flexilite
        PRIVATE
        -DSQLITE_ENABLE_FTS4
        -DSQLITE_ENABLE_RTREE
        -DSQLITE_ENABLE_LOAD_EXTENSION
        -DSQLITE_ENABLE_JSON1
        -DLUAJIT_ENABLE_LUA52COMPAT
        -DLSQLITE_EXTENSION
        -DENABLE_CJSON_GLOBAL
        -DLUAJIT_ENABLE_GC64
        -DLSQLITE_EXTENSION
        -DSQLITE_EXTENSION
)

if (WIN32)
    target_link_libraries(Flexilite PRIVATE ${LuaJit_static})
else ()
    target_link_libraries(Flexilite PUBLIC ${LuaJit_static})
endif ()

target_link_libraries(Flexilite PUBLIC ${Flexilite_LuaFiles})

if (WIN32)
    set_target_properties(Flexilite PROPERTIES LINK_FLAGS "/WHOLEARCHIVE:${Flexilite_LuaFiles}")
endif ()


###############################################################################
project(flexish_cli C)

message("Building on: ${CMAKE_SYSTEM_NAME}")

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

include_directories(
        lib/sqlite
        lib/torch-luajit-rocks/luajit-2.1/src
        lib/luafilesystem/src
        lib/lua-cjson
)

ADD_CUSTOM_TARGET(
        Compile_Flexish_LuaFiles
        ALL
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/flexish
        COMMAND luajit ../tools/lua2lib.lua ./filelist.lua -n libFlexishLua.a --output ../obj_lua
        COMMENT "Compiling Flexish Lua files"
)

set(FLEXISH_SRC_FILES
        lib/lua-sqlite/sqlite3.c
        lib/lua-sqlite/lsqlite3.c
        lib/lua-cjson/fpconv.c
        lib/lua-cjson/lua_cjson.c
        lib/lua-cjson/strbuf.c
        lib/lua-base64/lbase64.c
        lib/luafilesystem/src/lfs.c
        flexish/run.c
        flexish/main.c
        )

add_executable(flexish_cli ${FLEXISH_SRC_FILES})

target_compile_definitions(flexish_cli
        PRIVATE
        -DSQLITE_ENABLE_FTS4
        -DSQLITE_ENABLE_RTREE
        -DSQLITE_ENABLE_LOAD_EXTENSION
        -DSQLITE_ENABLE_JSON1
        -DENABLE_CJSON_GLOBAL
        -DLUAJIT_ENABLE_LUA52COMPAT
        -DENABLE_CJSON_GLOBAL
        -DLUAJIT_ENABLE_GC64
        )

IF (WIN32)
    SET(Flexish_static_link ${CMAKE_CURRENT_SOURCE_DIR}/obj_lua/libFlexishLua/libFlexishLua.a)
ELSEIF (APPLE)
    SET(Flexish_static_link -Wl,-all_load ${CMAKE_CURRENT_SOURCE_DIR}/obj_lua/libFlexishLua/libFlexishLua.a)
ELSE ()
    SET(Flexish_static_link -Wl,--whole-archive ${CMAKE_CURRENT_SOURCE_DIR}/obj_lua/libFlexishLua/libFlexishLua.a -Wl,--no-whole-archive -Wl,-E)
ENDIF ()

if (WIN32)
    target_link_libraries(flexish_cli PRIVATE ${LuaJit_static})
    target_link_libraries(flexish_cli PRIVATE ${CMAKE_THREAD_LIBS_INIT} ${CMAKE_DL_LIBS})
else ()
    target_link_libraries(flexish_cli PUBLIC ${LuaJit_static})
endif ()

target_link_libraries(flexish_cli PUBLIC ${Flexish_static_link})

if (WIN32)
    # Needed to make all Lua objects public
    set_target_properties(flexish_cli PROPERTIES LINK_FLAGS "/WHOLEARCHIVE:${Flexish_static_link}")
endif ()


###############################################################################
# test
add_subdirectory(test)
