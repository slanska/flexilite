cmake_minimum_required(VERSION 3.5)

enable_testing()

message(WARNING "Platform: ${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}-${PLATFORM}")
set(PLATFORM "${CMAKE_SYSTEM_NAME}")
string(TOUPPER "${PLATFORM}" PLATFORM)

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

project(flexilite_test)

set(CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS} -std=c99")

add_definitions(-DSQLITE_ENABLE_FTS4
        -DSQLITE_ENABLE_RTREE
        -DSQLITE_ENABLE_LOAD_EXTENSION
        -DSQLITE_ENABLE_JSON1
        -DSQLITE_CORE)

include_directories(
        ../lib/cmocka/include
        ../lib/sqlite
        ../src/util
)

set(TEST_FILES
        ../lib/cmocka/src/cmocka.c
        ../lib/sqlite/sqlite3.c
        fts.c
        main.c
        fts.c
        util/db_init.c
        util/db_init.h
        definitions.h
        util/file_helper.c
        util/file_helper.h
        class.c
        sql_test_runner.c
        ../src/util/hash.c
        ../src/util/Array.c
        ../src/util/StringBuilder.c
        ../src/util/Path.c
        )

add_executable(flexilite_test ${TEST_FILES} )