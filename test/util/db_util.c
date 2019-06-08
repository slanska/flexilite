//
// Created by slanska on 2017-01-22.
//

#include "../definitions.h"

//SQLITE_EXTENSION_INIT3

int db_open_in_memory(sqlite3 **pDb)
{
    return db_create_or_open(":memory:", pDb);
}

int db_create_or_open(const char *zFile, sqlite3 **pDb)
{

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

    goto EXIT;

    ONERROR:
    if (*pDb)
    {
        sqlite3_close(*pDb);
        *pDb = NULL;
    }

    if (zErrMsg)
        printf("Error: %s", zErrMsg);

    EXIT:
    sqlite3_free(zErrMsg);
    sqlite3_free(zSql);

    return result;
}

void process_sqlite_error(sqlite3 *db)
{
    const char *zError = sqlite3_errmsg(db);

}

static int _flexi_create_from_json(sqlite3 *db, const char *zJSONPath, const char *zCommand)
{
    int result = 0;
    char *zBuf = NULL;

    CHECK_CALL(file_load_utf8(zJSONPath, &zBuf));

    sqlite3_stmt *pStmt = NULL;
    char *zSql = NULL;

    zSql = sqlite3_mprintf("select flexi('%s', :1);", zCommand);
    CHECK_STMT_PREPARE(db, zSql, &pStmt);
    sqlite3_bind_text(pStmt, 1, zBuf, -1, NULL);
    CHECK_STMT_STEP(pStmt, db);

    goto EXIT;

    ONERROR:
    assert_false(result);

    EXIT:
    if (pStmt)
        sqlite3_finalize(pStmt);
    sqlite3_free(zBuf);
    sqlite3_free(zSql);

    return result;
}

int flexi_create_schema_from_json_file(sqlite3 *db, const char *zJSONPath)
{
    return _flexi_create_from_json(db, zJSONPath, "create schema");
}

int flexi_create_class_from_json_file(sqlite3 *db, const char *zJSONPath)
{
    return _flexi_create_from_json(db, zJSONPath, "create class");
}

