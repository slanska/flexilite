//
// Created by slanska on 2017-01-21.
//

/*
 * SQLite extension functions are registered here
 */

#include <stddef.h>
#include "../lib/sqlite/sqlite3ext.h"

SQLITE_EXTENSION_INIT3

static void flexi_prop_create_func()
{

}

int flexi_prop_create_register(sqlite3 *db,
                            char **pzErrMsg,
                            const sqlite3_api_routines *pApi) {
    int result = sqlite3_create_function_v2(db, "flexi_prop_create", 1, SQLITE_UTF8, flexi_prop_create_func,
                                        NULL, 0, 0, NULL);

    return result;
}


