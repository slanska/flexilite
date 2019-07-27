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

static void create_Northwind(void **state)
{
    int result = 0;
    sqlite3 *pDB = *state;

    // Create schema
    CHECK_CALL(flexi_create_schema_from_json_file(pDB, NORTHWIND_DB3_SCHEMA_JSON));

    goto EXIT;

    ONERROR:
    printf("Error %d, %s", sqlite3_errcode(pDB), sqlite3_errmsg(pDB));
    EXIT:
    printf("create_Northwind: %p", pDB);
}

static void create_Chinook(void **state)
{
    int result = 0;
    sqlite3 *pDB = *state;

    // Create schema
    CHECK_CALL(flexi_create_schema_from_json_file(pDB, CHINOOK_DB3_SCHEMA_JSON));

    goto EXIT;

    ONERROR:
    printf("Error %d, %s", sqlite3_errcode(pDB), sqlite3_errmsg(pDB));
    EXIT:
    printf("create_Chinook: %p", pDB);
}

int run_flexi_import_data_tests(sqlite3 *pDB)
{
    const struct CMUnitTest tests[] = {
            cmocka_unit_test_state(create_Northwind, pDB),
            cmocka_unit_test_state(create_Chinook, pDB),
    };
    return cmocka_run_group_tests(tests, NULL, NULL);
}

#ifdef __cplusplus
}
#endif
