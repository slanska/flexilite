cmake_minimum_required(VERSION 3.5)

enable_testing()

#message(WARNING "Platform: ${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}-${PLATFORM}")
set(PLATFORM "${CMAKE_SYSTEM_NAME}")
string(TOUPPER "${PLATFORM}" PLATFORM)

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

project(flexilite_test)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
#set(CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS} -std=c99")

add_definitions(-DSQLITE_ENABLE_FTS4
        -DSQLITE_ENABLE_RTREE
        -DSQLITE_ENABLE_LOAD_EXTENSION
        -DSQLITE_ENABLE_JSON1
        -DSQLITE_CORE
        -DHAVE_SIGNAL_H)

include_directories(
        ../lib/cmocka/include
        ../lib/sqlite
        ../src/util
)

find_package(Threads REQUIRED)

set(TEST_FILES

        ../lib/cmocka/src/cmocka.c
        ../lib/sqlite/sqlite3.c
        fts.c
        main.cpp
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


#add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../lib/luajit-2.1 ${CMAKE_CURRENT_BINARY_DIR}/lib/luajit-2.1)

add_executable(flexilite_test ${TEST_FILES} )

target_link_libraries(flexilite_test ${CMAKE_THREAD_LIBS_INIT} ${CMAKE_DL_LIBS})
