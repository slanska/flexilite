cmake_minimum_required(VERSION 2.8)

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

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

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

add_definitions(-DSQLITE_ENABLE_FTS4
        -DSQLITE_ENABLE_RTREE
        -DSQLITE_ENABLE_LOAD_EXTENSION
        -DSQLITE_ENABLE_JSON1)

add_executable(sqlite_shell ${SHELL_FILES})

# Note libraries are linked AFTER executable is registered
# also, using 'm' for standard math library
target_link_libraries(sqlite_shell ${CMAKE_THREAD_LIBS_INIT} ${CMAKE_DL_LIBS})
target_link_libraries(sqlite_shell m)

# libFlexilite library
project(Flexilite)

include_directories(
        lib/sqlite
        lib/luajit-2.1/src
        src/util
)

add_custom_target(Generate_Resources
        ALL
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMAND xxd -i sql/dbschema.sql > src/resources/dbschema.res.h
        COMMENT "Generating resource file for SQL schema."
        DEPENDS sql/dbschema.sql)

set_source_files_properties(src/resources/dbschema.res.h PROPERTIES GENERATED TRUE)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_definitions(-DRESOURCES_GENERATED
        )

set(EXT_FILES
        # version of lsqlite for extension library (using sqlite3ext.h instead of sqlite3.h)
        src/lua-sqlite/lsqlite3.c
        lib/lua-cjson/fpconv.c
        lib/lua-cjson/lua_cjson.c
        lib/lua-cjson/strbuf.c
        src/misc/json1.c
        src/typings/DBDefinitions.h
        src/project_defs.h
        src/main.cpp

        # compress.c is temporarily disabled because of the following error: Undefined symbols for architecture x86_64:
        #        "_compress", referenced from:
        #        src/misc/compress.c
        src/misc/eval.c
        src/misc/fileio.c
        src/misc/regexp.c
        src/misc/totype.c
        #        src/_old_flexilite/flexi_get.c
        src/misc/var.c

        src/util/hash.c

        src/misc/hash.c

        src/misc/memstat.c
        #        src/flexi/flexi_data.cpp

        #        src/flexi/flexi_class.cpp
        #        src/flexi/flexi_class_alter.cpp
        #        src/flexi/flexi_props_to_object.c

        src/fts/fts3_expr.c
        src/fts/fts3_tokenizer.c
        src/fts/fts3_hash.c
        #        src/flexi/flexi_prop.c
        #        src/flexi/flexi_prop_merge.c
        #        src/flexi/flexi_query.cpp
        #        src/util/json_proc.c
        src/common/common.h
        src/util/Array.c
        src/util/Array.h
        src/flexi/flexi_func.cpp

        #        src/flexi/flexi_prop_merge.h
        #        src/flexi/flexi_db_ctx.cpp
        #        src/flexi/flexi_db_ctx.h
        #        src/flexi/flexi_UserInfo_t.c
        #        src/flexi/flexi_UserInfo_t.h
        #        src/util/rbtree.c
        #        src/flexi/class_ref_def.c
        #        src/flexi/class_ref_def.h
        #        src/util/List.c
        #        src/util/List.h
        src/util/Path.c
        src/util/Path.h
        src/util/StringBuilder.c
        src/util/StringBuilder.h
        #        src/flexi/flexi_data_adhoc.c
        #        src/flexi/flexi_data_vtable.c
        #        src/flexi/class_build_json.c
        #        src/flexi/flexi_data.h
        #        src/flexi/flexi_Object.c
        #        src/flexi/flexi_Object.h
        #        src/flexi/flexi_PropValue.c
        #        src/flexi/flexi_PropValue.h
        #        src/flexi/DBContext.cpp
        #        src/flexi/DBContext.h
        src/flexi/ClassDef.cpp
        src/flexi/ClassDef.h
        src/flexi/PropertyDef.cpp
        src/flexi/PropertyDef.h
        #        src/DukContext.h src/DukContext.cpp
        )

#set(CMAKE_FIND_LIBRARY_SUFFIXES ".so")
#set(CMAKE_FIND_LIBRARY_SUFFIXES ".dylib")
#set(CMAKE_FIND_LIBRARY_SUFFIXES ".dll")
set(CMAKE_FIND_LIBRARY_PREFIXES "")

# Register Flexilite DLL/SO/DYLIB
# Link to luajit statically

add_subdirectory(lib/luajit-2.1)

#add_subdirectory(lib/lua-cjson)

add_library(Flexilite SHARED ${EXT_FILES})

target_link_libraries(Flexilite PUBLIC luajit-static)

#set_target_properties(Flexilite PROPERTIES COMPILE_FLAGS "-m32" LINK_FLAGS "-m32")
#set_target_properties(Flexilite PROPERTIES COMPILE_FLAGS "-m64" LINK_FLAGS "-m64")

add_custom_target(install_${PROJECT_NAME}
        make install
        DEPENDS ${PROJECT_NAME}
        COMMENT "Installing ${PROJECT_NAME}")


# flexilite_test

#project(flexilite_test)
#
#set(CMAKE_CXX_STANDARD 11)
#set(CMAKE_CXX_STANDARD_REQUIRED ON)
###set(CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS} -std=c99")
#
#add_definitions(-DSQLITE_ENABLE_FTS4
#        -DSQLITE_ENABLE_RTREE
#        -DSQLITE_ENABLE_LOAD_EXTENSION
#        -DSQLITE_ENABLE_JSON1
#        -DSQLITE_CORE
#        -DHAVE_SIGNAL_H)
#
#include_directories(
#        lib/sqlite
#        lib/luajit-2.1/src
#        lib/cmocka/include
#        src/util
#)
#
#find_package(Threads REQUIRED)
#
#set(TEST_FILES
#
##        lib/lua-sqlite/lsqlite3.c
##        lib/lua-cjson/fpconv.c
##        lib/lua-cjson/lua_cjson.c
##        lib/lua-cjson/strbuf.c
#
#        lib/cmocka/src/cmocka.c
#        lib/sqlite/sqlite3.c
#
#        src/util/hash.c
#        src/util/Array.c
#        src/util/StringBuilder.c
#        src/util/Path.c
#
#        test/fts.c
#        test/main.cpp
#        test/fts.c
#        test/util/db_init.c
#        test/util/db_init.h
#        test/definitions.h
#        test/util/file_helper.c
#        test/util/file_helper.h
##        test/class.c
#        test/sql_test_runner.c
#        )
#
#add_executable(flexilite_test ${TEST_FILES})
#
#target_link_libraries(flexilite_test ${CMAKE_THREAD_LIBS_INIT} ${CMAKE_DL_LIBS})
#target_link_libraries(flexilite_test libluajit)
##target_link_libraries(flexilite_test m)
#
