//
// Created by slanska on 2017-02-11.
//

#include "../project_defs.h"

int flexi_init(sqlite3 *pDb, sqlite3_context *pCtx) {

#include "../resources/dbschema.res.h"

    char *zError;
    int result  = sqlite3_exec(pDb, (const char*)sql_dbschema_sql, NULL, NULL, &zError);
    return result;
}

