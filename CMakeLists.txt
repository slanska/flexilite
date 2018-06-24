# libFlexish CMakeLists.txt - static library (lua, sqlite, lsqlite ...)
# src (Flexilite) - libFlexilite-static ->
# luajit - static and shared library
# test - static lib libFlexiliteTest-static (sqlite, tests)

# main CMakeLists.txt - b
# EXE sqlite_shell
# EXE flexish - flexish/main.c + libFlexish + luajit-static
# LIB Flexilite - libFlexilite.dylib/so/dll : libFlexilite-static + luajit
# EXE flexi_test - libFlexiliteTest-static

cmake_minimum_required(VERSION 3.0.2 FATAL_ERROR)

enable_testing()

if (WIN32)
    add_definitions(-D_CRT_SECURE_NO_WARNINGS)
endif ()

#CMake provides three variables to describe the system:
#
#CMAKE_SYSTEM_NAME (Window, Linux, Darwin),
#CMAKE_SYSTEM_PROCESSOR (depends on the OS, for instance i386 on Linux, x86 on Windows, etc.)
#CMAKE_SYSTEM_VERSION (depends on the OS too)

set(CMAKE_BINARY_DIR "${CMAKE_CURRENT_SOURCE_DIR}")

#message(WARNING "Platform: ${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}")
#message(WARNING "Platform: ${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}-${PLATFORM}")
set(PLATFORM "${CMAKE_SYSTEM_NAME}")
string(TOUPPER "${PLATFORM}" PLATFORM)

#set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin/${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR})
#set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin/${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

project(sqlite_shell)

message("Building on: ${CMAKE_SYSTEM_NAME}")

#set_property(TARGET tgt PROPERTY C_STANDARD 99)

if (${CMAKE_SYSTEM_NAME} MATCHES "Windows")
    find_package(zlib REQUIRED)
else ()
    find_package(ZLIB REQUIRED)
endif ()

find_package(Threads REQUIRED)

set(SHELL_FILES
        lib/sqlite/shell.c
        lib/sqlite/sqlite3.c
        )

add_definitions(
        -DSQLITE_ENABLE_FTS4
        -DSQLITE_ENABLE_RTREE
        -DSQLITE_ENABLE_LOAD_EXTENSION
        -DSQLITE_ENABLE_JSON1
        -DLUAJIT_ENABLE_LUA52COMPAT
        -DSQLITE_EXTENSION
        -DLSQLITE_EXTENSION
        )

add_executable(sqlite_shell ${SHELL_FILES})

# Note libraries are linked AFTER executable is registered
# also, using 'm' for standard math library
target_link_libraries(sqlite_shell ${CMAKE_THREAD_LIBS_INIT} ${CMAKE_DL_LIBS})
target_link_libraries(sqlite_shell m)

###############################################################################
# libFlexilite library
project(Flexilite)

include_directories(
        lib/sqlite
        lib/torch-lua/luajit-2.1/src
        src/util
)

ADD_CUSTOM_TARGET(
        Compile_Flexilite_LuaFiles
        ALL
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMAND luajit ./util/lua2lib.lua ./src_lua/filelist.lua -n libFlexiliteLua.a --output ./obj_lua
        COMMENT "Compiling Flexilite Lua files"
)

add_custom_target(
        Generate_Resources
        ALL
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMAND xxd -i sql/dbschema.sql > src/resources/dbschema.res.h
        COMMENT "Generating resource file for SQL schema."
        DEPENDS sql/dbschema.sql
)

set_source_files_properties(src/resources/dbschema.res.h PROPERTIES GENERATED TRUE)

IF (WIN32)
    message('Windows: Flexilite')
    SET(Flexilite_LuaFiles -Wl,--whole-archive ${CMAKE_CURRENT_SOURCE_DIR}/obj_lua/libFlexiliteLua/libFlexiliteLua.a -Wl,--no-whole-archive -Wl,-E)
    SET(LuaJit_static ${CMAKE_CURRENT_SOURCE_DIR}/lib/torch-lua/build/luajit-2.1/libluajit-static.a)
ELSEIF (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    message('OSX: Flexilite')
    SET(Flexilite_LuaFiles -Wl,-all_load ${CMAKE_CURRENT_SOURCE_DIR}/obj_lua/libFlexiliteLua/libFlexiliteLua.a)
    SET(LuaJit_static ${CMAKE_CURRENT_SOURCE_DIR}/lib/torch-lua/build/luajit-2.1/libluajit-static.a)
ELSE ()
    message('Linux: Flexilite')
    SET(Flexilite_LuaFiles -Wl,--whole-archive ${CMAKE_CURRENT_SOURCE_DIR}/obj_lua/libFlexiliteLua/libFlexiliteLua.a -Wl,--no-whole-archive -Wl,-E)
    SET(LuaJit_static ${CMAKE_CURRENT_SOURCE_DIR}/lib/torch-lua/build/luajit-2.1/libluajit-static.a)
ENDIF ()

add_definitions(
        -DSQLITE_ENABLE_FTS4
        -DSQLITE_ENABLE_RTREE
        -DSQLITE_ENABLE_LOAD_EXTENSION
        -DSQLITE_ENABLE_JSON1
        -DLUAJIT_ENABLE_LUA52COMPAT
        -DLSQLITE_EXTENSION
        -DRESOURCES_GENERATED
        )

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(EXT_FILES
        lib/lua-sqlite/lsqlite3.c
        lib/lua-cjson/fpconv.c
        lib/lua-cjson/lua_cjson.c
        lib/lua-cjson/strbuf.c
        lib/lua-base64/lbase64.c

        src/misc/json1.c
        src/typings/DBDefinitions.h
        src/project_defs.h
        src/main.cpp

        src/misc/eval.c
        src/misc/fileio.c
        src/misc/regexp.c
        src/misc/totype.c
        src/misc/var.c

        src/util/hash.c

        src/misc/hash.c

        src/misc/memstat.c

        src/fts/fts3_expr.c
        src/fts/fts3_tokenizer.c
        src/fts/fts3_hash.c

        src/common/common.h
        src/util/Array.c
        src/util/Array.h
        src/flexi/flexi_func.cpp

        src/util/Path.c
        src/util/Path.h
        src/util/StringBuilder.c
        src/util/StringBuilder.h

        src/flexi/ClassDef.cpp
        src/flexi/ClassDef.h
        src/flexi/PropertyDef.cpp
        src/flexi/PropertyDef.h
        )

#set(CMAKE_FIND_LIBRARY_SUFFIXES ".so")
#set(CMAKE_FIND_LIBRARY_SUFFIXES ".dylib")
#set(CMAKE_FIND_LIBRARY_SUFFIXES ".dll")
set(CMAKE_FIND_LIBRARY_PREFIXES "")

# TODO Register Flexilite DLL/SO/DYLIB
# Link to luajit statically

set(CMAKE_MACOSX_RPATH 1)

add_library(Flexilite SHARED ${EXT_FILES})

target_link_libraries(Flexilite PUBLIC ${LuaJit_static})
target_link_libraries(Flexilite PUBLIC ${Flexilite_LuaFiles})

# Then link the libmyluafiles.a library into your main program using
# -Wl,--whole-archive -lmyluafiles -Wl,--no-whole-archive -Wl,-E.
#set(CMAKE_STATIC_LINKER_FLAGS "-Wl")
#target_link_libraries(Flexilite PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/libLuaModules.a)

###############################################################################
add_subdirectory(flexish)

project(flexish_cli)

# SQLite and LuaJIT compile flags
#add_definitions(-DSQLITE_ENABLE_FTS4
#        -DSQLITE_ENABLE_RTREE
#        -DSQLITE_ENABLE_LOAD_EXTENSION
#        -DSQLITE_ENABLE_JSON1
#        -DLUAJIT_ENABLE_LUA52COMPAT)
#
#remove_definitions(-DLSQLITE_EXTENSION)
#remove_definitions(-DSQLITE_EXTENSION)

message("Building on: ${CMAKE_SYSTEM_NAME}")

include_directories(
        lib/sqlite
        lib/torch-lua/luajit-2.1/src
)

set(SRC_FILES
        flexish/main.c
        )


#set (CMAKE_SHARED_LINKER_FLAGS "-Wl,--as-needed")
#set(CMAKE_STATIC_LINKER_FLAGS "-Wl,--whole-archive -llibFlexish_static -Wl,--no-whole-archive -Wl,-E -pagezero_size 10000 -image_base 100000000")

#SET(${CMAKE_CURRENT_SOURCE_DIR}/obj_lua/libFlexish/libFlexish.a -Wl,--whole-archive MY_LIB -Wl,--no-whole-archive)
add_executable(flexish_cli ${SRC_FILES})

IF (WIN32)
    message('Windows: Flexish')
    # TODO
#    SET(LuaJit_static -Wl,--whole-archive ${CMAKE_CURRENT_SOURCE_DIR}/lib/torch-lua/build/luajit-2.1/libluajit-static.a)
#    target_link_libraries(flexish_cli STATIC PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/lib/torch-lua/build/luajit-2.1/libluajit-static.a)
    SET(Flexish_static_link -Wl,--whole-archive ${CMAKE_CURRENT_SOURCE_DIR}/obj_lua/libFlexishLua/libFlexishLua.a -Wl,--no-whole-archive -Wl,-E)
ELSEIF (APPLE)
    # TODO Conditionally: only on OSX 64 bit
    message('OSX: Flexish')
#    set ( CMAKE_EXE_LINKER_FLAGS "-pagezero_size 10000 -image_base 100000000 ${CMAKE_EXE_LINKER_FLAGS}" )
#    SET(LuaJit_static -Wl,-all_load ${CMAKE_CURRENT_SOURCE_DIR}/lib/torch-lua/build/luajit-2.1/libluajit-static.a)
#    target_link_libraries(flexish_cli STATIC PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/lib/torch-lua/build/luajit-2.1/libluajit-static.a)
    SET(Flexish_static_link -Wl,-all_load ${CMAKE_CURRENT_SOURCE_DIR}/obj_lua/libFlexishLua/libFlexishLua.a)
ELSE ()
    message('Linux: Flexish')

#    SET(LuaJit_static -Wl,--whole-archive ${CMAKE_CURRENT_SOURCE_DIR}/lib/torch-lua/build/luajit-2.1/libluajit-static.a)
#    target_link_libraries(flexish_cli STATIC ${CMAKE_CURRENT_SOURCE_DIR}/lib/torch-lua/build/luajit-2.1/libluajit-static.a)
    SET(Flexish_static_link -Wl,--whole-archive ${CMAKE_CURRENT_SOURCE_DIR}/obj_lua/libFlexishLua//libFlexishLua.a -Wl,--no-whole-archive -Wl,-E)
ENDIF ()

#target_link_libraries(flexish_cli PUBLIC ${LuaJit_static})
target_link_libraries(flexish_cli PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/lib/torch-lua/build/luajit-2.1/libluajit-static.a)
target_link_libraries(flexish_cli PUBLIC FlexishStatic)
target_link_libraries(flexish_cli PUBLIC ${Flexish_static_link})

###############################################################################
# test
#add_subdirectory(test)
