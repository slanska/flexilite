cmake_minimum_required(VERSION 3.5)

enable_testing()

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

set(CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS} -std=c99")

find_package(zlib)

set(SHELL_FILES
        lib/sqlite/shell.c
        lib/sqlite/sqlite3.c
        )

add_definitions(-DSQLITE_ENABLE_FTS4
        -DSQLITE_ENABLE_RTREE
        -DSQLITE_ENABLE_LOAD_EXTENSION
        -DSQLITE_ENABLE_JSON1)

add_executable(sqlite_shell ${SHELL_FILES})

# libFlexilite library
project(Flexilite)

#add_custom_command(
#        OUTPUT src/resources/dbschema.res
#        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
#        COMMAND xxd -i sql/dbschema.sql > src/resources/dbschema.res.h
#        COMMENT "Generating resource file for SQL schema."
#        DEPENDS sql/dbschema.sql
#)

add_custom_target(Generate_Resources
        ALL
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMAND xxd -i sql/dbschema.sql > src/resources/dbschema.res.h
        COMMENT "Generating resource file for SQL schema."
        DEPENDS sql/dbschema.sql)

set_source_files_properties(src/resources/dbschema.res.h PROPERTIES GENERATED TRUE)

#if (NOT XXD_SQL_RESULT EQUAL 0)
#    message(FATAL_ERROR "Failed to generate resource file for SQL schema")
#endif ()

set(CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS} -std=c99")

set(EXT_FILES
#        lib/sqlite/sqlite3ext.h

        src/misc/json1.c
        src/typings/DBDefinitions.h
        src/main.c

        # compress.c is temporarily disabled because of the following error: Undefined symbols for architecture x86_64:
        #        "_compress", referenced from:
        #        src/misc/compress.c
        src/misc/eval.c
        src/misc/fileio.c
        src/misc/regexp.c
        src/misc/totype.c
        src/_old_flexilite/flexi_get.c
        src/misc/var.c

        src/util/hash.c
        #        src/util/hash.h

        src/misc/hash.c

        src/misc/memstat.c
        src/flexi/flexieav_vtable.c
        #        src/flexi/flexi_eav.h

        #        src/misc/regexp.h

        lib/duktape/duktape.c
#        lib/duktape/duktape.h

        src/flexi/flexi_class.c
        src/flexi/flexi_class_alter.c
        src/flexi/flexi_props_to_object.c

        src/fts/fts3_expr.c
        #        src/fts/fts3Int.h
        src/fts/fts3_tokenizer.c
        #        src/fts/fts3_tokenizer.h
        src/fts/fts3_hash.c
        #        src/fts/fts3_hash.h
        src/flexi/flexi_prop_create.c
        src/flexi/flexi_prop_merge.c
        src/flexi/flexi_data_vtable.c
        src/flexi/flexi_query.c
        src/functions.c
        src/util/json_proc.c
        src/common/common.h
#        src/resources/dbschema.res.h
        src/util/buffer.c
        src/util/buffer.h
#        src/flexi/flexi_class.h
        src/flexi/flexi_func.c

        )

set(CMAKE_FIND_LIBRARY_SUFFIXES ".so")
set(CMAKE_FIND_LIBRARY_PREFIXES "")
#set(CMAKE_FIND_LIBRARY_PREFIXES "lib")

add_library(Flexilite SHARED ${EXT_FILES})

add_custom_target(install_${PROJECT_NAME}
        make install
        DEPENDS ${PROJECT_NAME}
        COMMENT "Installing ${PROJECT_NAME}")

add_subdirectory(test)

