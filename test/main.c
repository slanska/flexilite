//
// Created by slanska on 2017-01-18.
//

#include "definitons.h"

/* A test case that does nothing and succeeds. */
static void null_test_success(void **state) {
    (void) state; /* unused */
}

int main() {
    printf("Test !!!\n");

    const struct CMUnitTest tests[] = {
            cmocka_unit_test(null_test_success),
    };
    return cmocka_run_group_tests(tests, NULL, NULL);

}