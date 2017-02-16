//
// Created by slanska on 2017-02-13.
//

#include "definitions.h"

//SQLITE_EXTENSION_INIT3

static void create_class_Employee(void **state) {

}

static void create_class_Orders(void **state) {
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

    sqlite3_stmt *pStmt = NULL;
    const char *zTail = NULL;
    CHECK_CALL(sqlite3_prepare(db, "select flexi_schema_init(:schema);", -1, &pStmt, &zTail));
    sqlite3_bind_text(pStmt, 0, zBuf, -1, NULL);
    CHECK_STMT(sqlite3_step(pStmt));


    goto FINALLY;

    CATCH:
    assert_false(result);

    FINALLY:
    if (pStmt)
        sqlite3_finalize(pStmt);
    if (db)
        sqlite3_close(db);
    if (zBuf)
        sqlite3_free(zBuf);
}

int class_tests() {
    const struct CMUnitTest tests[] = {
            cmocka_unit_test(create_class_Employee),
            cmocka_unit_test(create_class_Orders),
    };
    return cmocka_run_group_tests(tests, NULL, NULL);
}