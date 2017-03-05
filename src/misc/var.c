//
// Created by slanska on 2016-03-13.
//

#include "../project_defs.h"

#include "../util/hash.h"

static void sqlVarFunc(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    assert(argc == 1 || argc == 2);

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

    sqlite3_value *value = HashTable_get_v(varHash, varName);
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
            HashTable_set_v(varHash, varName, NULL);
        }
        else
        {
            sqlite3_value *newValue = sqlite3_value_dup(argv[1]);
            HashTable_set_v(varHash, varName, newValue);
        }
    }
    else
    {
        sqlite3_free(varName);
    }
}

/*
 *
 */
static void sqlVarFunc_Destroy(void *userData)
{
    struct Hash *varHash = userData;
    if (varHash)
        HashTable_clear(varHash);
    sqlite3_free(varHash);
}

int var_func_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
)
{
    struct Hash *varHash = sqlite3_malloc(sizeof(struct Hash));
    HashTable_init(varHash, DICT_STRING, NULL);

    int rc = sqlite3_create_function_v2(db, "var", 1, SQLITE_UTF8, varHash,
                                    sqlVarFunc, 0, 0, sqlVarFunc_Destroy);
    if (rc == SQLITE_OK)
    {
        //Note that we pass destroy function only once. to avoid multiple callbacks
        rc = sqlite3_create_function_v2(db, "var", 2, SQLITE_UTF8, varHash,
                                        sqlVarFunc, 0, 0, 0);
    }

    return rc;
}

