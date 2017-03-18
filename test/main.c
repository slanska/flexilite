//
// Created by slanska on 2017-01-18.
//

// Using linked version of SQLite

//#define SQLITE_CORE

#include <stdint.h>
#include <string.h>
#include "definitions.h"

/* A test case that does nothing and succeeds. */
static void init_memory_db(void **state)
{

    struct sqlite3 *pDb;
    db_open_in_memory(&pDb);
    assert_non_null(pDb);
    sqlite3_close(pDb);
    pDb = NULL;
}

/* A test case that does nothing and succeeds. */
static void init_db(void **state)
{
    struct sqlite3 *pDb;
    db_create_or_open("../../data/test5.db", &pDb);
    assert_non_null(pDb);
    sqlite3_close(pDb);
    pDb = NULL;
}

int main()
{
    run_sql_tests("../../test/json/sql-test.class.json");
}