//
// Created by slanska on 2016-03-12.
//

#include "main.h"

#ifdef _WIN32
__declspec(dllexport)
#endif

int sqlite3_extension_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
) {
    // eval
    int result = sqlite3_eval_init(db, pzErrMsg, pApi);

    // fileio
    if (result == 0)
    {
        result = sqlite3_fileio_init(db, pzErrMsg, pApi);
    }

    // regexp
    if (result == 0)
    {
        result = sqlite3_regexp_init(db, pzErrMsg, pApi);
    }

    // totype
    if (result == 0)
    {
        result = sqlite3_totype_init(db, pzErrMsg, pApi);
    }

    // var
    if (result == 0)
    {
        result = sqlite3_var_init(db, pzErrMsg, pApi);
    }

    // flexi_get
    if (result == 0)
    {
        result = sqlite3_flexi_get_init(db, pzErrMsg, pApi);
    }

    // hash
    if (result == 0)
    {
        result = sqlite3_hash_init(db, pzErrMsg, pApi);
    }

    return result;
}