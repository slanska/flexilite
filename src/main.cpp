//
// Created by slanska on 2016-03-12.
//

#include "main.h"
#include <cstdlib>
//#include "../lib/parson_json/parson.h"
#include <memory>
#include "flexi/DBContext.h"

#ifdef _WIN32
__declspec(dllexport)
#endif

extern "C" int sqlite3_extension_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
)
{
    SQLITE_EXTENSION_INIT2(pApi);

//    auto ctx = std::unique_ptr<DBContext>(new DBContext(db));

    // Use sqlite3 memory API for JSON operations
    //  TODO  json_set_allocation_functions(static_cast<JSON_Malloc_Function>(sqlite3_malloc), sqlite3_free);

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