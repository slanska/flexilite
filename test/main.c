//
// Created by slanska on 2017-01-18.
//

// Using linked version of SQLite

//#define SQLITE_CORE

#include <stdint.h>
#include <string.h>
#include <zconf.h>
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

int main(int argc, char** argv)
{
    char* zDir = NULL;
    Path_dirname(&zDir, *argv);

    // TODO temp
    char zCurrentDir[PATH_MAX + 1];
    getcwd(zCurrentDir, PATH_MAX);

    if (zDir == NULL || strlen(zDir) == 0 || strcmp(zDir, ".") == 0)
    {
        sqlite3_free(zDir);
        zDir = sqlite3_mprintf("%s", zCurrentDir);
    }
    printf("Current directory: %s, zDir: %s\n", zCurrentDir, zDir);

    run_sql_tests(zDir, "../../test/json/sql-test.class.json");
    sqlite3_free(zDir);
}