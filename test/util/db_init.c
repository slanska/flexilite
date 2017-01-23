//
// Created by slanska on 2017-01-22.
//

#include "db_init.h"

sqlite3 * db_open_in_memory() {
    sqlite3 *pDb;
    int result = sqlite3_open(":memory", &pDb);

    // load and run db schema

    // load and run init

    // load extension library

    // check if it is loaded and working

    return pDb;
}

int db_create_or_open(const char *zFile) {
    return SQLITE_OK;
}
