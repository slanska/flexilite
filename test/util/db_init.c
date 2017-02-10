//
// Created by slanska on 2017-01-22.
//

#include "../../src/project_defs.h"
#include "db_init.h"
#include "file_helper.h"

int db_open_in_memory(sqlite3 **pDb) {
    return db_create_or_open(":memory:", pDb);
}

int db_create_or_open(const char *zFile, sqlite3 **pDb) {

    int result = SQLITE_OK;

    *pDb = NULL;
    char *zErrMsg = NULL;

    CHECK_CALL(sqlite3_enable_shared_cache(1));

    CHECK_CALL(sqlite3_open_v2(zFile, pDb,
                               SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_SHAREDCACHE,
                               NULL));

    CHECK_CALL(sqlite3_enable_load_extension(*pDb, 1));

    // load extension library
    CHECK_CALL(sqlite3_load_extension(*pDb, "../../bin/libflexilite", NULL, &zErrMsg));

    // load and run db schema
    char *zSql = NULL;
    CHECK_CALL(file_load_utf8("../../sql/dbschema.sql", &zSql));
    CHECK_CALL(sqlite3_exec(*pDb, (const char *) zSql, NULL, NULL, &zErrMsg));

    CHECK_CALL(sqlite3_exec(*pDb, "select var('Foo', 'Boo');", NULL, NULL, &zErrMsg));

    goto FINALLY;

    CATCH:
    if (*pDb) {
        sqlite3_close(*pDb);
        *pDb = NULL;
    }

    if (zErrMsg)
        printf("Error: %s", zErrMsg);

    FINALLY:
    sqlite3_free(zErrMsg);
    sqlite3_free(zSql);

    return result;
}
