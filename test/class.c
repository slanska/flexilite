//
// Created by slanska on 2017-02-13.
//

#include "definitions.h"

static void create_class_Employee(void **state) {

}

static void create_class_Orders(void **state) {
    sqlite3 *db = NULL;
    int result = 0;
    char *zBuf = NULL;
    CHECK_CALL(db_open_in_memory(&db));

    file_load_utf8("json/Northwind.db3.schema.json", &zBuf);

    CATCH:
    assert_false(result);
    FINALLY:
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