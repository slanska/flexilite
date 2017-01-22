cmake_minimum_required(VERSION 3.5)

enable_testing()

#CMake provides three variables to describe the system:
#
#CMAKE_SYSTEM_NAME (Window, Linux, Darwin),
#CMAKE_SYSTEM_PROCESSOR (depends on the OS, for instance i386 on Linux, x86 on Windows, etc.)
#CMAKE_SYSTEM_VERSION (depends on the OS too)

set(CMAKE_BINARY_DIR "${CMAKE_CURRENT_SOURCE_DIR}")

#message(WARNING "Platform: ${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}")
message(WARNING "Platform: ${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}-${PLATFORM}")
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

add_executable(sqlite_shell ${SHELL_FILES})

project(flexilite)

# project (flexilite_test)

set(CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS} -std=c99")

set(EXT_FILES
#        src/project_defs.h
#        lib/sqlite/sqlite3ext.h

        src/typings/DBDefinitions.h
        #main.c

        # compress.c is temporarily disabled because of the following error: Undefined symbols for architecture x86_64:
        #        "_compress", referenced from:
        #        src/misc/compress.c
        src/misc/eval.c
        src/misc/fileio.c
        src/misc/regexp.c
        src/misc/totype.c
        src/_old_flexilite/flexi_get.c
        src/misc/var.c
        src/misc/json1.c

        src/util/hash.c
#        src/util/hash.h

        src/misc/hash.c

        src/misc/memstat.c
        src/_old_flexilite/flexi_json_value.c
        src/flexi/flexieav_vtable.c
#        src/flexi/flexi_eav.h

#        src/misc/regexp.h
        #        lmdb/libraries/liblmdb/midl.h
        #        lmdb/libraries/liblmdb/mdb.c
        #        lmdb/libraries/liblmdb/midl.c
        #        lmdb/libraries/liblmdb/lmdb.h

        lib/duktape/duktape.c
        lib/duktape/duktape.h

        src/flexi/flexi_class_alter.c
        src/flexi/flexi_props_to_object.c

        src/fts/fts3_expr.c
#        src/fts/fts3Int.h
        src/fts/fts3_tokenizer.c
#        src/fts/fts3_tokenizer.h
        src/fts/fts3_hash.c
#        src/fts/fts3_hash.h
        src/flexi/flexi_import_data.c
        src/flexi/flexi_prop_create.c
        src/flexi/flexi_prop_merge.c
        src/flexi/flexi_query.c
        src/functions.c
        )

set(CMAKE_FIND_LIBRARY_SUFFIXES ".so")
set(CMAKE_FIND_LIBRARY_PREFIXES "")
#set(CMAKE_FIND_LIBRARY_PREFIXES "lib")

add_library(flexilite SHARED ${EXT_FILES})

add_custom_target(install_${PROJECT_NAME}
        make install
        DEPENDS ${PROJECT_NAME}
        COMMENT "Installing ${PROJECT_NAME}")

