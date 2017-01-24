//
// Created by slanska on 2017-01-18.
//

#include "definitions.h"
#include "util/db_init.h"

/* A test case that does nothing and succeeds. */
static void init_memory_db(void **state) {
    struct sqlite3 *pDb;
    db_open_in_memory(&pDb);
    assert_non_null(pDb);
    sqlite3_close(pDb);
    pDb = NULL;
}

/* A test case that does nothing and succeeds. */
static void init_db(void **state) {
    struct sqlite3 *pDb;
    db_create_or_open("../../data/test5.db", &pDb);
    assert_non_null(pDb);
    sqlite3_close(pDb);
    pDb = NULL;
}

int main() {
    const struct CMUnitTest tests[] = {
            cmocka_unit_test(init_memory_db),
            cmocka_unit_test(init_db),
    };
    return cmocka_run_group_tests(tests, NULL, NULL);
}