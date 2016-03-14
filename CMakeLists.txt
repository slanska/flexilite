cmake_minimum_required(VERSION 3.4)

set(CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS} -std=c99")

project(sqlite_shell)

find_package(zlib)

set(SHELL_FILES
        lib/sqlite/shell.c
        lib/sqlite/sqlite3.c
        )

add_executable(sqlite_shell ${SHELL_FILES})

project(sqlite_extensions)

set (EXT_FILES
        src/main.c

        # compress.c is temporarily disabled because of the following error: Undefined symbols for architecture x86_64:
#        "_compress", referenced from:
#        src/misc/compress.c
        src/misc/eval.c
        src/misc/fileio.c
        src/misc/regexp.c
        src/misc/totype.c
        src/flexilite/flexi_get.c
        src/misc/var.c
        src/misc/json1.c)

add_library(sqlite_extensions SHARED ${EXT_FILES})


