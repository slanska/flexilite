//
// Created by slanska on 2016-03-12.
//

#include "main.h"

extern "C"
#ifdef _WIN32
__declspec(dllexport)
#endif
 int sqlite3_extension_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
)
{
    SQLITE_EXTENSION_INIT2(pApi);

    int (*funcs[])(sqlite3 *, char **, const sqlite3_api_routines *) = {
            eval_func_init,
            fileio_func_init,
            regexp_func_init,
            totype_func_init,
            var_func_init,
            hash_func_init,
            memstat_func_init,
            flexi_init
    };

    for (int idx = 0; idx < sizeof(funcs) / sizeof(funcs[0]); idx++)
    {
        int result = funcs[idx](db, pzErrMsg, pApi);
        if (result != SQLITE_OK)
            return result;
    }

    return SQLITE_OK;
}