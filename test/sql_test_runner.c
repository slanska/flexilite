//
// Created by slanska on 2017-02-15.
//

/*
 * General SQL script runner
 */

#include "definitions.h"
#include "../src/util/buffer.h"
#include "../src/util/hash.h"

static void _run_sql_test(void **state)
{}

static int _setup_sql_test(void **state)
{
    // Start transaction
    return 0;
}

static int _teardown_sql_test(void **state)
{
    // Rollback transaction
    return 0;
}

static void _free_test_item(void *item)
{

    sqlite3_free(item);
}

/*
 * Loads array of test definitions from given JSON file (which should follow structure presented below)
 * and runs tests for all items in loaded JSON array
 */
void run_sql_tests(const char *zJsonFile)
{

    int result = SQLITE_OK;

    int nTestCount = 0;
    struct CMUnitTest *pTests = NULL;

    const char *zError = NULL;

    // Read JSON file
    char *zJson = NULL;
    CHECK_CALL(file_load_utf8(zJsonFile, &zJson));

    // Open memory database
    sqlite3 *db = NULL;
    CHECK_CALL(sqlite3_open(":memory:", &db));

    const unsigned char *prevColValues[12];
    const unsigned char *colValues[12];

    memset(&prevColValues, 0, sizeof(prevColValues));
    memset(&colValues, 0, sizeof(colValues));

    char *zSelJSON = sqlite3_mprintf("select json_extract(value, '$.include') as [include], " // 0
                                             "json_extract(value, '$.describe') as [describe], " // 1
                                             "json_extract(value, '$.it') as [it], " // 2
                                             "json_extract(value, '$.inDb') as [inDb], " // 3
                                             "json_extract(value, '$.inSql') as [inSql], " // 4
                                             "json_extract(value, '$.inArgs') as [inArgs], " // 5
                                             "json_extract(value, '$.inFileArgs') as [inFileArgs], " // 6
                                             "json_extract(value, '$.chkDb') as [chkDb], " // 7
                                             "json_extract(value, '$.chkSql') as [chkSql], " // 8
                                             "json_extract(value, '$.chkArgs') as [chkArgs], " // 9
                                             "json_extract(value, '$.chkFileArgs') as [chkFileArgs], " // 10
                                             "json_extract(value, '$.chkResult') as [chkResult] " // 11
                                             "from json_each('%s')", zJson);

    sqlite3_stmt *pJsonStmt = NULL;
    CHECK_CALL(sqlite3_prepare(db, zSelJSON, -1, &pJsonStmt, NULL));
    while ((result = sqlite3_step(pJsonStmt)) == SQLITE_OK)
    {
        int iCol;
        for (iCol = 0; iCol < sizeof(colValues) / sizeof(colValues[0]); iCol++)
        {
            colValues[iCol] = sqlite3_column_text(pJsonStmt, iCol);
            if (!colValues[iCol] && iCol != 0) // except include
                colValues[iCol] = prevColValues[iCol];
        }

        if (colValues[1])
        {}

    }
    if (result != SQLITE_DONE)
        goto CATCH;

    //    Buffer pBuf;

    //    Buffer_init(&pBuf, sizeof(struct CMUnitTest), NULL);
    struct CMUnitTest *pt = sqlite3_malloc(sizeof(struct CMUnitTest *));
    //    Buffer_append(&pBuf, &pt);
    memset(pt, 0, sizeof(*pt));
    pt->name = "";
    pt->test_func = _run_sql_test;
    pt->setup_func = _setup_sql_test;
    pt->teardown_func = _teardown_sql_test;

    // Execute JSON

    // Iterate over items in JSON file and prepare tests
    //    CHECK_CALL(cmocka_run_group_tests(const char *group_name,
    //                                const struct CMUnitTest * const tests,
    //                                const size_t num_tests,
    //                                CMFixtureFunction group_setup,
    //                                CMFixtureFunction group_teardown));
    //
    goto FINALLY;

    CATCH:

    FINALLY:
    // Deallocate all resources
    sqlite3_free(zJson);
    sqlite3_free(zSelJSON);
    sqlite3_free(pTests);
    sqlite3_free(zError);

    return;
}



