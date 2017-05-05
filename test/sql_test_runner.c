//
// Created by slanska on 2017-02-15.
//

/*
 * General SQL script runner
 */

#include <stdint.h>
#include <stdlib.h>
#include "definitions.h"

/*
 * Creates exact copy of original string zSrc.
 * New string has to be disposed by caller
 * Returns pointer to a new string or NULL if allocation failed
 */
static char *strCopy(const char *zSrc, int len)
{
    if (len < 0)
        len = (int) strlen(zSrc);

    char *result = sqlite3_malloc(len + 1);
    if (result != NULL)
    {
        strncpy(result, zSrc, len);
        result[len] = 0;
    }
    return result;
}

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
    TEST_DEF_PROP_CHK_RESULT = 11,
    TEST_DEF_ENTRY_FILE_PATH = 12,
    TEST_DEF_PROP_IN_SUBST = 13,
    TEST_DEF_PROP_CHK_SUBST = 14,

    TEST_DEF_PROP_LAST_INDEX = 14
};

typedef struct SqlTestData_t
{
    char *props[TEST_DEF_PROP_LAST_INDEX + 1];
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

static int
_testGroupSetup(void **state)
{
    // TODO
    return 0;
}

static int
_testGroupTeardown(void **state)
{
    // TODO
    return 0;
}

static void
_freeSqliteValue(sqlite3_value **pVal)
{
    sqlite3_value_free(*pVal);
}

typedef struct SqlArg_t
{
    /*
    * Normally, arguments are coming directly from test definition JSON
    */
    sqlite3_value *pValue;

    /*
     * Or, alternatively, loaded from external text file (if FileArgs are used)
     */
    char *zText;
} SqlArg_t;

static void
_freeSqlArg(SqlArg_t *p)
{
    sqlite3_value_free(p->pValue);
    sqlite3_free(p->zText);
}

static void _bindSqlArg(const char *zKey, const sqlite3_int64 index, SqlArg_t *pArg,
                        const Array_t *arr, sqlite3_stmt *pStmt, bool *bStop)
{
    UNUSED_PARAM(zKey);
    UNUSED_PARAM(arr);
    UNUSED_PARAM(bStop);

    if (pArg->zText)
        sqlite3_bind_text(pStmt, (int) index + 1, pArg->zText, -1, NULL);
    else sqlite3_bind_value(pStmt, (int) index + 1, pArg->pValue);
}

/*
 * Executes SQL statement zSql on zDatabase, using parameters zArgs and file name substitutions zFileArgs
 * Result data is loaded onto pData, and pRowCnt and pColCnt will indicate number of loaded rows and
 * number of columns in the row. Total number of items in pData will be nRowCnt * nColCnt
 */
static int
_runSql(char *zDatabase, char *zSrcSql, char *zArgs, char *zFileArgs, Array_t *pData, int *pColCnt,
        char *zEntryFilePath,
        char *zSubstFileNames)
{
    int result;

    sqlite3 *pDB = NULL;
    sqlite3_stmt *pStmt = NULL;
    sqlite3_stmt *pArgsStmt = NULL;
    Array_t sqlArgs;
    char *zError = NULL;
    char *zFullFilePath = NULL;
    sqlite3_stmt *pSubstStmt = NULL;
    char *zFileContent = NULL;

    char *zSql = strCopy(zSrcSql, -1);

    /*
    * Only first 16 substitute parameters will be processed. This is related to the fact that in C there
    * is no non-hacking way to dynamically build variadic arguments. So, to support list of values we just
    * limit maximum number of substitute strings to reasonably high number (16)
    */
    const char *zz[16];
    memset(&zz, 0, sizeof(zz));

    Array_init(&sqlArgs, sizeof(SqlArg_t), (void *) _freeSqlArg);

    *pColCnt = 0;

    //    Array_init(pData, sizeof(sqlite3_value *), (void *) _freeSqliteValue);

    /*
    * Open database (use :memory: if not defined)
    */
    if (zDatabase == NULL || strlen(zDatabase) == 0)
    {
        zDatabase = ":memory:";
    }
    CHECK_CALL(sqlite3_open_v2(zDatabase, &pDB,
                               SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_SHAREDCACHE,
                               NULL));

    CHECK_CALL(sqlite3_enable_load_extension(pDB, 1));

    // load extension library
    CHECK_CALL(sqlite3_load_extension(pDB, "../../bin/libFlexilite", NULL, &zError));

    // load and run db schema
    char *zSchemaSql = NULL;
    CHECK_CALL(file_load_utf8("../../sql/dbschema.sql", &zSchemaSql));
    CHECK_CALL(sqlite3_exec(pDB, (const char *) zSchemaSql, NULL, NULL, &zError));

    /*
     * Substitute strings
     */
    if (!STR_EMPTY(zSubstFileNames))
    {
        CHECK_STMT_PREPARE(pDB, "select key, value from json_each(:1);", &pSubstStmt);
        CHECK_CALL(sqlite3_bind_text(pSubstStmt, 1, zSubstFileNames, -1, NULL));
        int nSubst = 0;
        while ((result = sqlite3_step(pSubstStmt)) == SQLITE_ROW)
        {
            if (nSubst >= 16)
            {
                result = SQLITE_ERROR;
                zError = "Number of substitute strings must not exceed 16";
                goto ONERROR;
            }
            sqlite3_free(zFullFilePath);
            zFullFilePath = NULL;

            Path_join(&zFullFilePath, zEntryFilePath, (char *) sqlite3_column_text(pSubstStmt, 1));

            CHECK_CALL(file_load_utf8(zFullFilePath, &zFileContent));

            zz[nSubst++] = zFileContent;
            zFileContent = NULL; // Memory will be freed by zz
        }
        if (result != SQLITE_DONE)
            goto ONERROR;

        char *zTemp = zSql;
        zSql = sqlite3_mprintf(zTemp, zz[0], zz[1], zz[2], zz[3], zz[4], zz[5], zz[6], zz[7], zz[8],
                               zz[9], zz[10], zz[11], zz[12], zz[13], zz[14], zz[15]);
        sqlite3_free(zTemp);
    }

    // TODO use flexi('init')

    CHECK_STMT_PREPARE(pDB, zSql, &pStmt);

    // Check if we have arguments JSON. Prepare arguments
    if (!STR_EMPTY(zArgs))
    {
        CHECK_STMT_PREPARE(pDB, "select value, type from json_each(:1);", &pArgsStmt);
        CHECK_CALL(sqlite3_bind_text(pArgsStmt, 1, zArgs, -1, NULL));
        int nArgCnt = 0;
        while ((result = sqlite3_step(pArgsStmt)) == SQLITE_ROW)
        {
            SqlArg_t item;
            memset(&item, 0, sizeof(item));
            item.pValue = sqlite3_value_dup(sqlite3_column_value(pArgsStmt, 0));
            Array_setNth(&sqlArgs, sqlArgs.iCnt, &item);
            nArgCnt++;
        }

        if (result != SQLITE_DONE)
            goto ONERROR;

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
                sqlite3_free(zFullFilePath);
                zFullFilePath = NULL;

                SqlArg_t *arg = Array_getNth(&sqlArgs, (u32) argNo - 1);
                Path_join(&zFullFilePath, zEntryFilePath, (char *) sqlite3_value_text(arg->pValue));

                CHECK_CALL(file_load_utf8(zFullFilePath, &arg->zText));
            }
        }

        if (result != SQLITE_DONE)
            goto ONERROR;

        Array_each(&sqlArgs, (void *) _bindSqlArg, pStmt);
    }

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
        goto ONERROR;
    result = SQLITE_OK;
    goto EXIT;

    ONERROR:
    Array_clear(pData);
    if (pDB && zError == NULL)
    {
        zError = (char *) sqlite3_errmsg(pDB);
    }
    if (zError != NULL)
        printf("Error: %s", zError);

    EXIT:

    sqlite3_finalize(pStmt);
    sqlite3_finalize(pArgsStmt);
    sqlite3_finalize(pSubstStmt);
    if (pDB != NULL)
    {
        result = sqlite3_close(pDB);
        if (result != SQLITE_OK)
        {
            printf("DB Close Error %d. %s", result, sqlite3_errmsg(pDB));
        }
    }
    Array_clear(&sqlArgs);
    sqlite3_free(zFullFilePath);
    sqlite3_free(zSql);

    for (int i = 0; i < ARRAY_LEN(zz); i++)
        sqlite3_free((void *) zz[i]);

    if (zFileContent != NULL)
        sqlite3_free(zFileContent);

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
    Array_init(&testData, sizeof(sqlite3_value *), (void *) _freeSqliteValue);
    int nInColCnt;
    CHECK_CALL(
            _runSql(tt->props[TEST_DEF_PROP_IN_DB], tt->props[TEST_DEF_PROP_IN_SQL], tt->props[TEST_DEF_PROP_IN_ARGS],
                    tt->props[TEST_DEF_PROP_IN_FILE_ARGS], &testData, &nInColCnt, tt->props[TEST_DEF_ENTRY_FILE_PATH],
                    tt->props[TEST_DEF_PROP_IN_SUBST]));

    Array_t chkData;
    Array_init(&chkData, sizeof(sqlite3_value *), (void *) _freeSqliteValue);
    int nChkColCnt = 0;
    //    CHECK_CALL(_runSql(tt->props[TEST_DEF_PROP_CHK_DB], tt->props[TEST_DEF_PROP_CHK_SQL],
    //                       tt->props[TEST_DEF_PROP_CHK_ARGS], tt->props[TEST_DEF_PROP_CHK_FILE_ARGS], &chkData, &nChkColCnt,
    //                       tt->props[TEST_DEF_ENTRY_FILE_PATH], tt->props[TEST_DEF_PROP_CHK_SUBST]));
    //
    if (nChkColCnt > 0 && !_compareSqlData(&testData, nInColCnt, &chkData, nChkColCnt))
    {
        // Not passed
    }

    goto EXIT;

    ONERROR:

    EXIT:
    Array_clear(&testData);
    Array_clear(&chkData);

    assert_int_equal(result, SQLITE_OK);

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
 * Runs group of tests and clears tests at the end
 */
static int
_runTestGroup(char **pzGroupTitle, Array_t *tests)
{
    if (tests->iCnt == 0)
        return SQLITE_OK;

    if (!*pzGroupTitle)
        *pzGroupTitle = "SQL Tests";
    int result = _cmocka_run_group_tests(*pzGroupTitle,
                                         (void *) tests->items,
                                         tests->iCnt,
                                         _testGroupSetup,
                                         _testGroupTeardown
    );

    Array_clear(tests);
    return result;
}

static void
_disposeCMUnitTest(struct CMUnitTest *ut)
{
    // Note: no need to free name as it is also referenced from initial_state.props
    SqlTestData_clear(ut->initial_state);
    sqlite3_free(ut->initial_state);
}

/*
 * Loads array of test definitions from given JSON file (which should follow structure presented below)
 * and runs tests for all items in loaded JSON array
 *
 * if include - load external file, relative to the current one
 * file args - arguments are treated as file names and content from those files is injected as UTF8 strings
 */
void run_sql_tests(char *zBaseDir, const char *zJsonFile)
{
    int result;

    struct CMUnitTest *pTests = NULL;
    const char *zError = NULL;
    SqlTestData_t *testData = NULL;
    char *zDir = NULL;
    sqlite3 *db = NULL;
    char *zJsonBasePath = NULL;
    char *zJson = NULL;
    char *zJsonFileFull = NULL;
    Array_t tests;
    sqlite3_stmt *pJsonStmt = NULL;
    char *zGroupTitle = NULL;
    SqlTestData_t prevTestData;

    Array_init(&tests, sizeof(struct CMUnitTest), (void *) _disposeCMUnitTest);

    Path_join(&zJsonFileFull, zBaseDir, zJsonFile);
    Path_dirname(&zJsonBasePath, zJsonFileFull);

    // Read JSON file
    CHECK_CALL(file_load_utf8(zJsonFileFull, &zJson));

    // Open memory database
    CHECK_CALL(sqlite3_open(":memory:", &db));

    /*
     *     TEST_DEF_PROP_INCLUDE = 0,
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
    TEST_DEF_PROP_CHK_RESULT = 11,
    TEST_DEF_ENTRY_FILE_PATH = 12,
    TEST_DEF_PROP_IN_SUBST = 13,
    TEST_DEF_PROP_CHK_SUBST = 14,

     */
    const char *zSelJSON = "select json_extract(value, '$.include') as [include], " // 0
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
            "json_extract(value, '$.chkResult') as [chkResult], " // 11
            "json_extract(value, '$.entryFilePath') as [entryFilePath], " // 12
            "json_extract(value, '$.inSubst') as [inSubst], " // 13
            "json_extract(value, '$.chkSubst') as [chkSubst] " // 14
            "from json_each(:1);";

    SqlTestData_init(&prevTestData);

    CHECK_STMT_PREPARE(db, zSelJSON, &pJsonStmt);
    CHECK_CALL(sqlite3_bind_text(pJsonStmt, 1, zJson, -1, NULL));

    while ((result = sqlite3_step(pJsonStmt)) == SQLITE_ROW)
    {
        CHECK_MALLOC(testData, sizeof(*testData));
        SqlTestData_init(testData);
        int nCols = sqlite3_column_count(pJsonStmt);
        int iCol;
        for (iCol = 0; iCol < nCols; iCol++)
        {
            char *zVal = (char *) sqlite3_column_text(pJsonStmt, iCol);
            testData->props[iCol] = sqlite3_mprintf("%s", zVal);
            if (!testData->props[iCol] && iCol != TEST_DEF_PROP_INCLUDE)
                testData->props[iCol] = sqlite3_mprintf("%s", prevTestData.props[iCol]);
        }

        size_t nDirLen = strlen(zJsonBasePath) + 1;
        testData->props[TEST_DEF_ENTRY_FILE_PATH] = sqlite3_malloc((int) nDirLen);
        CHECK_NULL(testData->props[TEST_DEF_ENTRY_FILE_PATH]);
        strncpy(testData->props[TEST_DEF_ENTRY_FILE_PATH], zJsonBasePath, nDirLen);

        struct CMUnitTest test;
        test.name = testData->props[TEST_DEF_PROP_IT];
        test.test_func = _run_sql_test;
        test.initial_state = testData;

        // Now test is the owner of this data
        SqlTestData_t *initialState = testData;
        testData = NULL;

        test.setup_func = _setup_sql_test;
        test.teardown_func = _teardown_sql_test;

        Array_setNth(&tests, tests.iCnt, &test);
        if (zGroupTitle != NULL && strcmp(initialState->props[TEST_DEF_PROP_DESCRIBE], zGroupTitle) != 0)
        {
            CHECK_CALL(_runTestGroup(&zGroupTitle, &tests));
        }

        prevTestData = *initialState;
        zGroupTitle = initialState->props[TEST_DEF_PROP_DESCRIBE];
    }

    if (result != SQLITE_DONE)
        goto ONERROR;

    CHECK_CALL(_runTestGroup(&zGroupTitle, &tests));

    goto EXIT;

    ONERROR:

    if (db)
    {
        zError = sqlite3_errmsg(db);
        printf("Error: %s", zError);
    }

    EXIT:

    result = sqlite3_finalize(pJsonStmt);
    if (db != NULL)
    {
        result = sqlite3_close(db);
        if (result != SQLITE_OK)
        {
            printf("DB Close Error %d. %s", result, sqlite3_errmsg(db));
        }
    }
    Array_clear(&tests);
    SqlTestData_clear(testData);
    sqlite3_free(testData);
    sqlite3_free(zJson);
    sqlite3_free(pTests);
    sqlite3_free(zDir);
    sqlite3_free(zJsonBasePath);
    sqlite3_free(zJsonFileFull);

    assert_int_equal(result, SQLITE_OK);
}
