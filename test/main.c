//
// Created by slanska on 2017-01-18.
//

#include "definitions.h"
#include "util/db_init.h"

/* A test case that does nothing and succeeds. */
static void null_test_success(void **state) {
    struct sqlite3 *pDb = db_open_in_memory();
    assert_non_null(pDb);
    printf("In memory database was opened");
    sqlite3_close(pDb);
    pDb = NULL;
    (void) state; /* unused */
}

int main() {
    printf("Test !!!\n");

    const struct CMUnitTest tests[] = {
            cmocka_unit_test(null_test_success),
    };
    return cmocka_run_group_tests(tests, NULL, NULL);

}