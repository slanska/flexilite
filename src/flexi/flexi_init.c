//
// Created by slanska on 2017-02-11.
//

#include "../project_defs.h"

// Forward declarations
unsigned char sql_dbschema_sql[];
unsigned int sql_dbschema_sql_len;

int flexi_init(sqlite3 *pDb, sqlite3_context *pCtx) {

#include "../resources/dbschema.res.h"

    char *zError;
    sqlite3_exec(pDb, sql_dbschema_sql, NULL, NULL, &zError);
}

