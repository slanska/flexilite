//
// Created by slanska on 2017-02-15.
//

/*
 * General SQL script runner
 */

#include "definitions.h"
#include "../src/util/buffer.h"
#include "../src/util/hash.h"
#include "../src/util/Path.h"

/*
 * Column indexes in JSON test def
 */
enum TEST_DEF_PROP
{
    TEST_DEF_PROP_INCLUDE = 0,
    TEST_DEF_PROP_DESCRIBE = 1,
    TEST_DEF_PROP_IT = 2,
    TEST_DEF_PROP_IN_DB = 3,
    TEST_DEF_PROP_IN_SQL = 4,
    TEST_DEF_PROP_IN_ARGS = 5,
    TEST_DEF_PROP_IN_FILE_ARGS = 6,
    TEST_DEF_PROP_CHK_DB = 7,
    TEST_DEF_PROP_CHK_SQL = 8,
    TEST_DEF_PROP_CHK_ARGS = 9,
    TEST_DEF_PROP_CHK_FILE_ARGS = 10,
    TEST_DEF_PROP_CHK_RESULT = 11
};

typedef struct SqlTestData_t
{
    char *props[TEST_DEF_PROP_CHK_RESULT + 1];
} SqlTestData_t;

static void SqlTestData_init(SqlTestData_t *self)
{
    memset(self, 0, sizeof(*self));
}

static void SqlTestData_clear(SqlTestData_t *self)
{
    if (self)
    {
        for (int ii = 0; ii < ARRAY_LEN(self->props); ii++)
        {
            sqlite3_free(self->props[ii]);
        }
    }
}

/*
 * Single test handler
 */
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
 *
 * if include - load external file, relative to the current one
 * file args - arguments are treated as file names and content from those files is injected as UTF8 strings
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

    Buffer tests;
    Buffer_init(&tests, sizeof(struct CMUnitTest), NULL);

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

    SqlTestData_t prevTestData;
    SqlTestData_init(&prevTestData);

    CHECK_CALL(sqlite3_prepare(db, zSelJSON, -1, &pJsonStmt, NULL));
    while ((result = sqlite3_step(pJsonStmt)) == SQLITE_ROW)
    {
        SqlTestData_t *testData;
        CHECK_MALLOC(testData, sizeof(*testData));
        SqlTestData_init(testData);
        int iCol;
        for (iCol = 0; iCol < ARRAY_LEN(testData->props); iCol++)
        {
            testData->props[iCol] = (char *) sqlite3_column_text(pJsonStmt, iCol);
            if (!testData->props[iCol] && iCol != TEST_DEF_PROP_INCLUDE)
                testData->props[iCol] = prevTestData.props[iCol];
        }

        struct CMUnitTest test;
        test.name = testData->props[TEST_DEF_PROP_IT];
        test.test_func = _run_sql_test;
        test.initial_state = testData;
        Buffer_set(&tests, tests.iCnt, &test);

        if (testData->props[TEST_DEF_PROP_DESCRIBE])
            // Define new test group
        {
            Buffer_clear(&tests);
        }

        prevTestData = *testData;
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
    //    SqlTestData_clear(&prevTestData);

    return;
}



