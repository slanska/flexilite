//
// Created by slanska on 2019-05-19.
//

// Set of CMocka unit tests for flexirel virtual table

#include <stdarg.h>
#include <stddef.h>
#include <setjmp.h>
#include <cmocka.h>
#include "definitions.h"

#ifdef __cplusplus
extern "C" {
#endif

/* A test case that does nothing and succeeds. */
static void create_flexirel_vtable(void **state)
{
    int result = 0;
    sqlite3* pDB = *state;

    sqlite3_stmt *pStmt;
    CHECK_CALL(sqlite3_prepare(pDB, "select flexi('configure');", -1, &pStmt, NULL));
    CHECK_STMT_STEP(pStmt, pDB);

    printf("create_flexirel_vtable: %x", pDB);

    goto EXIT;

    ONERROR:
    EXIT:
    printf("Error %d, %s", sqlite3_errcode(pDB), sqlite3_errmsg(pDB));
}

int run_flexirel_vtable_tests(sqlite3 *pDB)
{
    const struct CMUnitTest tests[] = {
            cmocka_unit_test_state(create_flexirel_vtable, pDB),
    };
    return cmocka_run_group_tests(tests, NULL, NULL);
}

#ifdef __cplusplus
}
#endif
