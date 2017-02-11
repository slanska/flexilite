//
// Created by slanska on 2017-02-11.
//

#include "../project_defs.h"

extern unsigned char sql_dbschema_sql[];
extern unsigned int sql_dbschema_sql_len;

int flexi_init(sqlite3 *pDb, sqlite3_context *pCtx) {

#include "../resources/dbschema.res.h"

    sql_dbschema_sql[0] = ' ';
}

