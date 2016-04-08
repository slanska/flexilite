//
// Created by slanska on 2016-04-07.
//

#include <string.h>
#include <printf.h>
#include <assert.h>
#include "../../lib/sqlite/sqlite3ext.h"
#include "../misc/json1.h"
#include <string.h>

SQLITE_EXTENSION_INIT3


/*
 * Flexilite (https://github.com/slanska/flexilite) specific function.
 * Uses database structure defined in Flexilite database
 * Returns value adopted to be stored in JSON
 * BLOBs are converted to base64 strings
 * Optional second parameter defines type of value as it is declared in property
 * For NAME property type, string value will be stored/found in .names table
 * and result of function would be name ID
 * For DATE property type, string value will converted to Julian datetime as double
 * value
  */
static void sqlFlexiJsonValueFunc(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
}

/*
 *
 */
static void sqlFlexiJsonValue_Destroy(void *userData)
{
}

int sqlite3_flexi_json_value_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
)
{
    int rc = SQLITE_OK;

    (void) pzErrMsg;  /* Unused parameter */
    void *data = NULL;

    rc = sqlite3_create_function_v2(db, "flexi_json_value", 1, SQLITE_UTF8, data,
                                    sqlFlexiJsonValueFunc, 0, 0, sqlFlexiJsonValue_Destroy);
    if (rc == SQLITE_OK)
    {
        rc = sqlite3_create_function_v2(db, "flexi_json_value", 2, SQLITE_UTF8, data,
                                        sqlFlexiJsonValueFunc, 0, 0, 0);
    }
    return rc;
}

