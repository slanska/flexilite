//
// Created by slanska on 2017-01-18.
//

// Using linked version of SQLite

#ifdef _WIN32

#include <direct.h>

#define getcwd _getcwd // stupid MSFT "deprecation" warning
#else

#include <unistd.h>

#endif

#include <cstdint>
#include <cstring>
#include <climits>
// TODO #include <zconf.h>

#include "definitions.h"

int main(int argc, char **argv)
{
    char *zDir = nullptr;
    Path_dirname(&zDir, *argv);

    // TODO temp - getcwd does not seem to be supported by Universal Window Apps
    char zCurrentDir[PATH_MAX + 1];
    getcwd(zCurrentDir, PATH_MAX);

    if (zDir == nullptr || strlen(zDir) == 0 || strcmp(zDir, ".") == 0)
    {
        sqlite3_free(zDir);
        zDir = sqlite3_mprintf("%s", zCurrentDir);
    }
    printf("Current directory: %s, zDir: %s\n", zCurrentDir, zDir);

    sqlite3 *pDB = nullptr;
    char *zSchemaSql = nullptr;
    char *zError = nullptr;

    int result = SQLITE_OK;
    CHECK_CALL(sqlite3_open_v2(":memory:", &pDB,
                               SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_SHAREDCACHE,
                               nullptr));

    CHECK_CALL(sqlite3_enable_load_extension(pDB, 1));

    // load extension library
    CHECK_CALL(sqlite3_load_extension(pDB, "../../bin/libFlexilite", nullptr, &zError));

    // Enable debug mode
    {
        sqlite3_stmt *pStmt;
        CHECK_CALL(sqlite3_prepare(pDB, "select flexi('debugger', 1);", -1, &pStmt, nullptr));
        CHECK_STMT_STEP(pStmt, pDB);
        int iDebugMode;
        iDebugMode = sqlite3_column_int(pStmt, 0);
        printf("Flexi debugger: %d\n", iDebugMode);
    }

    // Flexi configure
    {
        sqlite3_stmt *pStmt;
        CHECK_CALL(sqlite3_prepare(pDB, "select flexi('configure');", -1, &pStmt, nullptr));
        CHECK_STMT_STEP(pStmt, pDB);
        const unsigned char *szText;
        szText = sqlite3_column_text(pStmt, 0);
        printf("\nFlexi configure %s\n", szText);
    }

    // Run tests, essentially
    run_flexi_import_data_tests(pDB);

    //    run_sql_tests(zDir, "../../test/json/sql-test.class.json");

    goto EXIT;

    ONERROR:
    if (zError != nullptr)
    {
        printf("Error %d, %s", sqlite3_errcode(pDB), zError);
    }
    else
    {
        printf("Error %d, %s", sqlite3_errcode(pDB), sqlite3_errmsg(pDB));
    }
    EXIT:
    sqlite3_free(zDir);
    sqlite3_close(pDB);

}

