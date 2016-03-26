//
// Created by slanska on 2016-03-13.
//

#include <assert.h>
#include <string.h>
#include <ctype.h>
#include "../../lib/sqlite/sqlite3ext.h"
#include "../util/hash.h"

SQLITE_EXTENSION_INIT3

static void sqlVarFunc(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    assert(argc == 1 || argc == 2);

    sqlite3_int64 memUsed = sqlite3_memory_used();

    struct Hash *varHash = sqlite3_user_data(context);
    const char *localVarName = (const char *) sqlite3_value_text(argv[0]);

    size_t keyLength = strlen(localVarName) + 1;
    char *varName = sqlite3_malloc((int) keyLength);
    const char *src_c = localVarName;
    char *dst_c = varName;
    while (*src_c)
    {
        *dst_c++ = (char) toupper(*src_c++);
    }

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
    else sqlite3_free(varName);

    sqlite3_int64 memUsed2 = sqlite3_memory_used();
}

/*
 *
 */
static void sqlVarFunc_Destroy(void *userData)
{
    struct Hash *varHash = userData;
    if (varHash)
        sqlite3HashClear(varHash);
    sqlite3_free(varHash);
}

#ifdef _WIN32
__declspec(dllexport)
#endif

int sqlite3_var_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
)
{
    int rc = SQLITE_OK;

    struct Hash *varHash = sqlite3_malloc(sizeof(struct Hash));
    sqlite3HashInit(varHash);

    rc = sqlite3_create_function_v2(db, "var", 1, SQLITE_UTF8, varHash,
                                    sqlVarFunc, 0, 0, sqlVarFunc_Destroy);
    if (rc == SQLITE_OK)
    {
        //Note that we pass destroy function only once. to avoid multiple callbacks
        rc = sqlite3_create_function_v2(db, "var", 2, SQLITE_UTF8, varHash,
                                        sqlVarFunc, 0, 0, 0);
    }

    return rc;
}

