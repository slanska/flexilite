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
    SQLITE_EXTENSION_INIT2(pApi);

    // eval
    int result = sqlite3_eval_init(db, pzErrMsg, pApi);

    // fileio
    if (result == 0) {
        result = sqlite3_fileio_init(db, pzErrMsg, pApi);
    }

    // regexp
    if (result == 0) {
        result = sqlite3_regexp_init(db, pzErrMsg, pApi);
    }

    // totype
    if (result == 0) {
        result = sqlite3_totype_init(db, pzErrMsg, pApi);
    }

    // var
    if (result == 0) {
        result = sqlite3_var_init(db, pzErrMsg, pApi);
    }

    // flexi_get
    if (result == 0) {
        result = sqlite3_flexi_get_init(db, pzErrMsg, pApi);
    }

    // hash
    if (result == 0) {
        result = sqlite3_hash_init(db, pzErrMsg, pApi);
    }

    // mem_used & mem_high_water
    if (result == 0) {
        result = sqlite3_memstat_init(db, pzErrMsg, pApi);
    }

    // _old_flexilite EAV module
    if (result == 0) {
        result = sqlite3_flexieav_vtable_init(db, pzErrMsg, pApi);
    }

    result = flexi_class_init(db, pzErrMsg, pApi);
    if (result == 0)
        result = flexi_init(db, pzErrMsg, pApi);

    return result;
}