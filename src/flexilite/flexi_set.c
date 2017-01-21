//
// Created by slanska on 2016-03-13.
//

#include <string.h>
#include <printf.h>
#include <assert.h>
#include "../lib/sqlite/sqlite3ext.h"
#include "../misc/json1.h"
#include <string.h>

SQLITE_EXTENSION_INIT3

/*
 * Flexilite (https://github.com/slanska/flexilite) specific function.
 * Uses database structure defined in Flexilite database
  */
static void sqlFlexiSetFunc(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
}

/*
 *
 */
static void sqlFlexiSet_Destroy(void *userData)
{
}

int sqlite3_flexi_set_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
)
{
    int rc = SQLITE_OK;

    (void) pzErrMsg;  /* Unused parameter */
    void *data = NULL;
    rc = sqlite3_create_function_v2(db, "flexi_get", 4, SQLITE_UTF8, data,
                                    sqlFlexiSetFunc, 0, 0, sqlFlexiSet_Destroy);
    if (rc == SQLITE_OK)
    {
        //Note that we pass destroy function only once. to avoid multiple callbacks
        rc = sqlite3_create_function_v2(db, "flexi_set", 5, SQLITE_UTF8, data,
                                        sqlFlexiSetFunc, 0, 0, 0);
    }
    return rc;
}