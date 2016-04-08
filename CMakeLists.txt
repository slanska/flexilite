cmake_minimum_required(VERSION 3.4)

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

set(CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS} -std=c89")

find_package(zlib)

set(SHELL_FILES
        lib/sqlite/shell.c
        lib/sqlite/sqlite3.c
        )

add_executable(sqlite_shell ${SHELL_FILES})

project(sqlite_extensions)

set(CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS} -std=c89")


set(EXT_FILES


        src/main.c

        # compress.c is temporarily disabled because of the following error: Undefined symbols for architecture x86_64:
        #        "_compress", referenced from:
        #        src/misc/compress.c
        src/misc/eval.c
        src/misc/fileio.c
        src/misc/regexp.c
        src/misc/totype.c
        src/flexilite/flexi_get.c
        src/flexilite/flexi_set.c
        src/misc/var.c
        src/misc/json1.c

        src/util/hash.c
        src/util/hash.h

        src/misc/hash.c

        src/misc/memstat.c
        src/flexilite/flexi_json_value.c src/flexilite/flexi_json_value.h)

add_library(sqlite_extensions SHARED ${EXT_FILES})

add_custom_target(install_${PROJECT_NAME}
        make install
        DEPENDS ${PROJECT_NAME}
        COMMENT "Installing ${PROJECT_NAME}")
