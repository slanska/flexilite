//
// Created by slanska on 2016-03-13.
//

#include "../../lib/sqlite/sqlite3ext.h"
#include "../util/hash.h"
#include <assert.h>

SQLITE_EXTENSION_INIT3

#include <string.h>

static void sqlVarFunc(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    assert(argc == 1 || argc == 2);

    struct Hash *varHash = sqlite3_user_data(context);
    const char *localVarName = (const char *) sqlite3_value_text(argv[0]);
    // varName is allocated in stack. Need to create global object
    size_t keyLength = strlen(localVarName) + 1;
    char *varName = sqlite3_malloc((int)keyLength);
    strncpy(varName, localVarName, keyLength);

    sqlite3_value *value = sqlite3HashFind(varHash, varName);
    if (value)
    {
        sqlite3_result_value(context, value);
    }
    else
    {
        sqlite3_result_null(context);
    }

    if (argc == 2)
    {
        int valueType = sqlite3_value_type(argv[1]);
        if (valueType == SQLITE_NULL)
        {
            sqlite3HashInsert(varHash, varName, NULL);
        }
        else
        {
            sqlite3_value *newValue = sqlite3_value_dup(argv[1]);
            sqlite3HashInsert(varHash, varName, newValue);
        }
    }
}

#ifdef _WIN32
__declspec(dllexport)
#endif

int sqlite3_var_init(
        sqlite3 *db,
        char **pzErrMsg,
        const  sqlite3_api_routines *pApi
)
{
    int rc = SQLITE_OK;
    SQLITE_EXTENSION_INIT2(pApi);

    struct Hash *varHash = sqlite3_malloc(sizeof(struct Hash));
    sqlite3HashInit(varHash);

    rc = sqlite3_create_function(db, "var", 1, SQLITE_UTF8, varHash,
                                 sqlVarFunc, 0, 0);
    if (rc == SQLITE_OK)
    {
        rc = sqlite3_create_function(db, "var", 2, SQLITE_UTF8, varHash,
                                     sqlVarFunc, 0, 0);
    }

    return rc;
}

