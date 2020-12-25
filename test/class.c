//
// Created by slanska on 2017-02-13.
//

#include "definitions.h"


static void create_class_Employee(void **state)
{

}

static void create_class_Orders(void **state)
{
    sqlite3 *db = NULL;
    int result = 0;
    char *zBuf = NULL;
    CHECK_CALL(db_open_in_memory(&db));

    CHECK_CALL(file_load_utf8(
#if defined( _WIN32 ) || defined( __WIN32__ ) || defined( _WIN64 )
                       "json\\Northwind.db3.schema.json",
#else
                       "json/Northwind.db3.schema.json",
#endif
                       &zBuf));

    Array_t *pBuf;
    sqlite3_stmt *pStmt = NULL;
    const char *zTail = NULL;
    CHECK_STMT_PREPARE(db, "select flexi_schema_init(:schema);", &pStmt);
    sqlite3_bind_text(pStmt, 0, zBuf, -1, NULL);
    CHECK_STMT_STEP(pStmt, db);


    goto EXIT;

    ONERROR:
    assert_false(result);

    EXIT:
    if (pStmt)
        sqlite3_finalize(pStmt);
    if (db)
        sqlite3_close(db);
    if (zBuf)
        sqlite3_free(zBuf);
}

int class_tests()
{
    const struct CMUnitTest tests[] = {
            cmocka_unit_test(create_class_Employee),
            cmocka_unit_test(create_class_Orders),
    };
    return cmocka_run_group_tests(tests, NULL, NULL);
}