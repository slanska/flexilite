//
// Created by slanska on 2016-03-12.
//

#include <stdio.h>
#include "main.h"
#include "flexi/flexi_module.h"

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

    int result;

    // Init 'flexi' module and Lua/Flexilite context
    FlexiliteContext_t* pDBCtx;
    result = flexi_init(db, pzErrMsg, pApi, &pDBCtx);
    if (result != SQLITE_OK)
    {
        return result;
    }
    result = memstat_func_init(db, pzErrMsg, pApi);
    if (result != SQLITE_OK)
    {
        return result;
    }

    // TODO register virtual table modules
    // TODO pass flexilite lua context
//    result = register_flexi_rel_vtable(db, pDBCtx);

    return SQLITE_OK;
}