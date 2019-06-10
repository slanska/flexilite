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
    sqlite3 *pDB = *state;

    // Create schema
    CHECK_CALL(flexi_create_schema_from_json_file(pDB, NORTHWIND_DB3_SCHEMA_JSON));

    // Create flexirel: EmployeeTerritories
    CHECK_CALL(run_sql(pDB, "create virtual table if not exists [EmployeesTerritories]\n"
                            "using flexi_rel ([EmployeeID], [TerritoryID], [Employees] hidden, [Territories] hidden);"));

    goto EXIT;

    ONERROR:
    printf("Error %d, %s", sqlite3_errcode(pDB), sqlite3_errmsg(pDB));
    EXIT:
    printf("create_flexirel_vtable: %p", pDB);
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
