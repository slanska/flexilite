//
// Created by slanska on 2016-03-13.
//

#include "../../lib/sqlite/sqlite3ext.h"

SQLITE_EXTENSION_INIT3

#include <string.h>

static void sqlVarFunc(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
) {

}

#ifdef _WIN32
__declspec(dllexport)
#endif

int sqlite3_var_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
) {
    int rc = SQLITE_OK;
    SQLITE_EXTENSION_INIT2(pApi);
    (void) pzErrMsg;  /* Unused parameter */
    rc = sqlite3_create_function(db, "var", 1, SQLITE_UTF8, 0,
                                 sqlVarFunc, 0, 0);
    if (rc == SQLITE_OK) {
        rc = sqlite3_create_function(db, "var", 2, SQLITE_UTF8, 0,
                                     sqlVarFunc, 0, 0);
    }
    return rc;
}

