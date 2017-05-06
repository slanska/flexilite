//
// Created by slanska on 2017-01-18.
//

// Using linked version of SQLite

//#define SQLITE_CORE

#include <stdint.h>
#include <string.h>
#include <limits.h>
#include <zconf.h>
#include "definitions.h"

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