//
// Created by slanska on 2017-02-15.
//

/*
 * General SQL script runner
 */

#include <stdint.h>
#include "definitions.h"
#include "../src/util/Array.h"
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
 * Executes SQL statement zSql on zDatabase, using parameters zArgs and file name substitutions zFileArgs
 * Result data is loaded onto pData, and pRowCnt and pColCnt will indicate number of loaded rows and
 * number of columns in the row. Total number of items in pData will be nRowCnt * nColCnt
 */
static int
_runSql(char *zDatabase, char *zSql, char *zArgs, char *zFileArgs,
        Array_t *pData, int *pColCnt)
{
    int result;
    /*
    * Open database (:memory: if not defined)
    */
    sqlite3 *pDB = NULL;
    sqlite3_stmt *pStmt = NULL;
    const char *zErr = NULL;
    sqlite3_stmt *pArgsStmt = NULL;
    Array_t sqlArgs;
    char *zFileName = NULL;
    char *zFileArgContent = NULL;
    Array_init(&sqlArgs, sizeof(sqlite3_value *), (void *) sqlite3_value_free);

    *pColCnt = 0;

    Array_init(pData, sizeof(sqlite3_value *), (void *) sqlite3_value_free);

    CHECK_CALL(sqlite3_open_v2(zDatabase, &pDB, 0, NULL));

    CHECK_CALL(sqlite3_prepare_v2(pDB, zSql, -1, &pStmt, &zErr));

    // Prepare arguments
    CHECK_CALL(sqlite3_prepare_v2(pDB, "select value, type from json_each(:1);", -1, &pArgsStmt, &zErr));
    CHECK_CALL(sqlite3_bind_text(pArgsStmt, 1, zArgs, -1, NULL));
    int nArgCnt = 0;
    while ((result = sqlite3_step(pArgsStmt)) == SQLITE_ROW)
    {
        char *zArg = (char *) sqlite3_column_text(pArgsStmt, 0);
        sqlite3_value *argVal = sqlite3_value_dup(sqlite3_column_value(pArgsStmt, 0));
        Array_setNth(&sqlArgs, sqlArgs.iCnt, &argVal);
        sqlite3_bind_value(pStmt, ++nArgCnt, argVal);
    }

    if (result != SQLITE_DONE)
        goto CATCH;
    /*
     * Process file args
     */

    CHECK_CALL(sqlite3_reset(pArgsStmt));
    CHECK_CALL(sqlite3_bind_text(pArgsStmt, 1, zFileArgs, -1, NULL));
    while ((result = sqlite3_step(pArgsStmt)) == SQLITE_ROW)
    {
        int argNo = sqlite3_column_int(pArgsStmt, 0);
        if (argNo >= 1 && argNo <= nArgCnt)
        {
            zFileName = (char *) sqlite3_value_text(*(sqlite3_value **) Array_getNth(&sqlArgs, (u32) argNo));
            file_load_utf8(zFileName, &zFileArgContent);
            sqlite3_bind_text(pStmt, argNo, zFileArgContent, -1, NULL);
            sqlite3_free(zFileName);
            zFileName = NULL;
            sqlite3_free(zFileArgContent);
            zFileArgContent = NULL;
        }
    }

    if (result != SQLITE_DONE)
        goto CATCH;


    while ((result = sqlite3_step(pStmt)) == SQLITE_ROW)
    {
        if (*pColCnt == 0)
            *pColCnt = sqlite3_column_count(pStmt);
        int iCol;
        for (iCol = 0; iCol < *pColCnt; iCol++)
        {
            sqlite3_value *pVal = sqlite3_value_dup(sqlite3_column_value(pStmt, iCol));
            Array_setNth(pData, pData->iCnt, &pVal);
        }
    }

    if (result != SQLITE_DONE)
        goto CATCH;

    result = SQLITE_OK;
    goto FINALLY;

    CATCH:
    Array_clear(pData);

    FINALLY:

    sqlite3_finalize(pStmt);
    sqlite3_finalize(pArgsStmt);
    sqlite3_free((void *) zErr);
    sqlite3_close(pDB);
    Array_clear(&sqlArgs);
    sqlite3_free(zFileArgContent);
    sqlite3_free(zFileName);
    sqlite3_free(zFileArgContent);

    return result;
}

static void
_compareSqliteValues(char *zKey, uint32_t idx, sqlite3_value **vv, Array_t *pTestValues,
                     Array_t *pChkValues, bool *pStop)
{

}

/*
 * Compares data loaded by 2 SQL statements (IN* and CHK*)
 * Returns true if data sets are 100% equal
 */
static bool
_compareSqlData(Array_t *pTestData, int nTestColCnt,
                Array_t *pChkData, int nChkColCnt)
{
    if (nTestColCnt != nChkColCnt)
        return false;

    int64_t iTestRowCnt = pTestData->iCnt / nTestColCnt;
    int64_t iChkRowCnt = pChkData->iCnt / nChkColCnt;

    if (iTestRowCnt != iChkRowCnt)
        return false;

    sqlite3_value **pStoppedAt = Array_each(pTestData, (void *) _compareSqliteValues, pChkData);
    if (*pStoppedAt)
    {
        return false;
    }

    return true;
}

/*
 * Single test handler
 */
static void _run_sql_test(void **state)
{
    SqlTestData_t *tt = *state;

    int result;

    Array_t testData;
    int nInColCnt;
    CHECK_CALL(_runSql(tt->props[TEST_DEF_PROP_IN_DB], tt->props[TEST_DEF_PROP_IN_SQL],
                       tt->props[TEST_DEF_PROP_IN_ARGS], tt->props[TEST_DEF_PROP_IN_FILE_ARGS],
                       &testData, &nInColCnt));

    Array_t chkData;
    int nChkColCnt;
    CHECK_CALL(_runSql(tt->props[TEST_DEF_PROP_CHK_DB], tt->props[TEST_DEF_PROP_CHK_SQL],
                       tt->props[TEST_DEF_PROP_CHK_ARGS], tt->props[TEST_DEF_PROP_CHK_FILE_ARGS],
                       &chkData, &nChkColCnt));

    if (!_compareSqlData(&testData, nInColCnt, &chkData, nChkColCnt))
    {
        // Not passed
    }

    goto FINALLY;

    CATCH:

    FINALLY:
    Array_clear(&testData);
    Array_clear(&chkData);

    return;
}

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

    Array_t tests;
    Array_init(&tests, sizeof(struct CMUnitTest), NULL);

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
    char *zPrevDescribe = NULL;

    CHECK_CALL(sqlite3_prepare(db, zSelJSON, -1, &pJsonStmt, NULL));

    bool done = false;
    while (!done)
    {
        result = sqlite3_step(pJsonStmt);

        done = result == SQLITE_DONE;
        if (result != SQLITE_ROW && !done)
            break;

        SqlTestData_t *testData = NULL;
        if (result == SQLITE_ROW)
        {
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
            test.setup_func = _setup_sql_test;
            test.teardown_func = _teardown_sql_test;

            Array_setNth(&tests, tests.iCnt, &test);
        }

        if (done ||
            (tests.iCnt > 0 && zPrevDescribe != NULL &&
             strcmp(testData->props[TEST_DEF_PROP_DESCRIBE], zPrevDescribe) != 0))
            // Run as a separate group
        {
            if (!zPrevDescribe)
                zPrevDescribe = "SQL Tests";
            CHECK_CALL(_cmocka_run_group_tests(zPrevDescribe,
                                               (void *) tests.items,
                                               tests.iCnt,
                                               NULL, //CMFixtureFunction group_setup,
                                               NULL // CMFixtureFunction group_teardown
            ));

            Array_clear(&tests);
        }

        prevTestData = *testData;
        zPrevDescribe = testData->props[TEST_DEF_PROP_DESCRIBE];
    }

    if (result != SQLITE_DONE)
        goto CATCH;

    goto FINALLY;

    CATCH:

    FINALLY:
    // Deallocate all resources
    Array_clear(&tests);
    sqlite3_free(zJson);
    sqlite3_free(zSelJSON);
    sqlite3_free(pTests);
    sqlite3_free(zError);
}



