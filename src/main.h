//
// Created by slanska on 2016-03-13.
//

#ifndef SQLITE_EXTENSIONS_MAIN_H
#define SQLITE_EXTENSIONS_MAIN_H

#include "../lib/sqlite/sqlite3ext.h"

SQLITE_EXTENSION_INIT1

int eval_func_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
);

int fileio_func_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
);

int regexp_func_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
);

int totype_func_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
);

int var_func_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
);

int hash_func_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
);

int sqlite3_flexi_get_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
);

int memstat_func_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
);

int flexi_data_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
);

int flexi_class_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi);

int flexi_init(sqlite3 *db,
               char **pzErrMsg,
               const sqlite3_api_routines *pApi);

#endif //SQLITE_EXTENSIONS_MAIN_H
