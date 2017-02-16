//
// Created by slanska on 2017-02-15.
//

/*
 * General SQL script runner
 */

#include "definitions.h"

//SQLITE_EXTENSION_INIT3

static void _run_sql_test(void **state) {}

static int _setup_sql_test(void **state) {
    // Start transaction
    return 0;
}

static int _teardown_sql_test(void **state) {
    // Rollback transaction
    return 0;
}

static void _free_test_item(void *item) {

    sqlite3_free(item);
}

/*
 *
 */
void run_sql_tests(const char *zJsonFile) {

    int result = SQLITE_OK;
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

    char *zSelJSON = sqlite3_mprintf("select json_extract(value, '$.include') as [include], "
                                             "json_extract(value, '$.describe') as [describe], "
                                             "json_extract(value, '$.it') as [it], "
                                             "json_extract(value, '$.inDb') as [inDb], "
                                             "json_extract(value, '$.inSql') as [inSql], "
                                             "json_extract(value, '$.inArgs') as [inArgs], "
                                             "json_extract(value, '$.inFileArgs') as [inFileArgs], "
                                             "json_extract(value, '$.chkDb') as [chkDb], "
                                             "json_extract(value, '$.chkSql') as [chkSql], "
                                             "json_extract(value, '$.chkArgs') as [chkArgs], "
                                             "json_extract(value, '$.chkFileArgs') as [chkFileArgs], "
                                             "json_extract(value, '$.chkResult') as [chkResult] "
                                             "from json_each('%s')", zJson);

    sqlite3_stmt *pJsonStmt = NULL;
    CHECK_CALL(sqlite3_prepare(db, zSelJSON, -1, &pJsonStmt, NULL));
    while ((result = sqlite3_step(pJsonStmt)) == SQLITE_OK) {
        int iCol;
        for (iCol = 0; iCol < sizeof(colValues) / sizeof(colValues[0]); iCol++) {
            colValues[iCol] = sqlite3_column_text(pJsonStmt, iCol);
            if (!colValues[iCol] && iCol != 0) // except include
                colValues[iCol] = prevColValues[iCol];
        }

        if (colValues[1]) {}

    }
    if (result != SQLITE_DONE)
        goto CATCH;

//    Buffer pBuf;

//    buffer_init(&pBuf, sizeof(struct CMUnitTest), NULL);
    struct CMUnitTest *pt = sqlite3_malloc(sizeof(struct CMUnitTest *));
//    buffer_append(&pBuf, &pt);
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
    return;
    // Deallocate all resources
}



