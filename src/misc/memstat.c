//
// Created by slanska on 2016-03-25.
//

#include "../../lib/sqlite/sqlite3ext.h"

SQLITE_EXTENSION_INIT3


#ifdef _WIN32
__declspec(dllexport)
#endif

static void sqlMemUsedFunc(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    sqlite3_int64 memUsed = sqlite3_memory_used();
    sqlite3_result_int(context, memUsed);

}

static void sqlMemHighWaterFunc(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    sqlite3_int64 memHW = sqlite3_memory_highwater(0);
    sqlite3_result_int(context, memHW);
}

int memstat_func_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
)
{
    int rc = SQLITE_OK;
    SQLITE_EXTENSION_INIT2(pApi);

    rc = sqlite3_create_function(db, "mem_used", 0, SQLITE_UTF8, 0,
                                 sqlMemUsedFunc, 0, 0);
    if (rc == SQLITE_OK)
    {
        rc = sqlite3_create_function(db, "mem_high_water", 0, SQLITE_UTF8, 0,
                                     sqlMemHighWaterFunc, 0, 0);
    }

    return rc;
}

