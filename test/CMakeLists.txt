cmake_minimum_required(VERSION 3.5)

enable_testing()

#message(WARNING "Platform: ${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}")
message(WARNING "Platform: ${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}-${PLATFORM}")
set(PLATFORM "${CMAKE_SYSTEM_NAME}")
string(TOUPPER "${PLATFORM}" PLATFORM)

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

project(flexilite_test)

set(CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS} -std=c99")

set(TEST_FILES
        ../lib/cmocka/src/cmocka.c
        ../lib/sqlite/sqlite3.c
        fts.c
        main.c
        fts.c vtable.c util/db_init.c util/db_init.h definitions.h util/file_helper.c util/file_helper.h)

add_executable(flexilite_test ${TEST_FILES})