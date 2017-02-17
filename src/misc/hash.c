//
// Created by slanska on 2016-03-22.
//

#include "../project_defs.h"

//#include "../../lib/sqlite/sqlite3ext.h"
#include "../util/hash.h"

SQLITE_EXTENSION_INIT3

//#include <string.h>
//#include <assert.h>

static void sqlHashFunc(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    assert(argc == 1);
    const char *localVarName = (const char *) sqlite3_value_text(argv[0]);
    unsigned int result = sqlite3StrHashValue(localVarName);
    sqlite3_result_int(context, result);
}


int hash_func_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
)
{
    int rc = SQLITE_OK;

    rc = sqlite3_create_function(db, "hash", 1, SQLITE_UTF8, NULL,
                                 sqlHashFunc, 0, 0);

    return rc;
}

