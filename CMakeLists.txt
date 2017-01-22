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

#set(SHELL_FILES
#        lib/sqlite/shell.c
#        lib/sqlite/sqlite3.c
#        )
#
#add_executable(sqlite_shell ${SHELL_FILES})

project(sqlite_extensions)

set(CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS} -std=c99")

set(EXT_FILES
        typings/DBDefinitions.h
        main.c

        # compress.c is temporarily disabled because of the following error: Undefined symbols for architecture x86_64:
        #        "_compress", referenced from:
        #        src/misc/compress.c
        misc/eval.c
        misc/fileio.c
        misc/regexp.c
        misc/totype.c
        _old_flexilite/flexi_get.c
        misc/var.c
        misc/json1.c

        util/hash.c
        util/hash.h

        misc/hash.c

        misc/memstat.c
        _old_flexilite/flexi_json_value.c
        flexi/flexieav_vtable.c
        flexi/flexi_eav.h

        misc/regexp.h
        #        lmdb/libraries/liblmdb/midl.h
        #        lmdb/libraries/liblmdb/mdb.c
        #        lmdb/libraries/liblmdb/midl.c
        #        lmdb/libraries/liblmdb/lmdb.h

        #        duktape-1.4.0/src/duktape.c
        #        duktape-1.4.0/src/duktape.h

        flexi/flexi_class_alter.c
        flexi/flexi_props_to_object.c

        fts/fts3_expr.c
        fts/fts3Int.h
        fts/fts3_tokenizer.c
        fts/fts3_tokenizer.h
        fts/fts3_hash.c
        fts/fts3_hash.h
        flexi/flexi_import_data.c flexi/flexi_prop_create.c flexi/flexi_prop_merge.c flexi/flexi_query.c functions.c src/project_defs.h)

set(CMAKE_FIND_LIBRARY_SUFFIXES ".dylib")
set(CMAKE_FIND_LIBRARY_PREFIXES "lib")

add_library(sqlite_extensions SHARED ${EXT_FILES})

add_custom_target(install_${PROJECT_NAME}
        make install
        DEPENDS ${PROJECT_NAME}
        COMMENT "Installing ${PROJECT_NAME}")

