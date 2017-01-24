//
// Created by slanska on 2017-01-22.
//

#ifndef FLEXILITE_DB_INIT_H
#define FLEXILITE_DB_INIT_H

#include "../definitions.h"

int db_open_in_memory(sqlite3 **pDb);

int db_create_or_open(const char *zFile, sqlite3 **pDb);

#endif //FLEXILITE_DB_INIT_H
