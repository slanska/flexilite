//
// Created by slanska on 2017-01-22.
//

#include "db_init.h"

int db_open_in_memory() {
    sqlite3 *pDb;
    int result = sqlite3_open_v2(":memory", &pDb, 0, 0);
    return result;
}

int db_create_or_open(const char *zFile) {
    return SQLITE_OK;
}
