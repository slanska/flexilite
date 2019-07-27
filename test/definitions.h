//
// Created by slanska on 2017-01-22.
//

#ifndef FLEXILITE_DEFINITIONS_H
#define FLEXILITE_DEFINITIONS_H

#include <stddef.h>
#include <setjmp.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#include <cmocka.h>
#include <sqlite3.h>

#include "../src/common/common.h"
#include "Array.h"
#include "util/db_util.h"
#include "util/file_helper.h"
#include "../src/util/Path.h"

// OS specific path constants
#if defined( _WIN32 ) || defined( __WIN32__ ) || defined( _WIN64 )
#define NORTHWIND_DB3_SCHEMA_JSON "..\\..\\test\\json\\Northwind.db3.schema.json"
#else
#define NORTHWIND_DB3_SCHEMA_JSON "../../test/json/Northwind.db3.schema.json"
#endif

#if defined( _WIN32 ) || defined( __WIN32__ ) || defined( _WIN64 )
#define CHINOOK_DB3_SCHEMA_JSON "..\\..\\test\\json\\Chinook.db.schema.json"
#else
#define CHINOOK_DB3_SCHEMA_JSON "../../test/json/Chinook.db.schema.json"
#endif

#ifdef __cplusplus
extern "C" {
#endif

int class_tests();

void run_sql_tests(char *zBaseDir, const char *zJsonFile);

int run_flexi_import_data_tests(sqlite3 *pDB);

/*
 * prop_tests();
 */

#ifdef __cplusplus
}
#endif

/** Initializes a CMUnitTest structure. */
#define cmocka_unit_test_state(f, initial_state) { #f, f, NULL, NULL, initial_state }

#endif //FLEXILITE_DEFINITIONS_H
