//
// Created by slanska on 2017-01-22.
//

#ifndef FLEXILITE_DB_INIT_H
#define FLEXILITE_DB_INIT_H

#include "../definitions.h"

int db_open_in_memory(sqlite3 **pDb);

int db_create_or_open(const char *zFile, sqlite3 **pDb);

void process_sqlite_error(sqlite3 *db);

int flexi_create_schema_from_json_file(sqlite3 *db, const char *zJSONPath);

int flexi_create_class_from_json_file(sqlite3 *db, const char *zJSONPath);

int run_sql(sqlite3 * db, const char* zSql);

int run_sql_from_file(sqlite3 *db, const char *zSQLPath);

#endif //FLEXILITE_DB_INIT_H
