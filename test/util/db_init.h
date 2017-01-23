//
// Created by slanska on 2017-01-22.
//

#ifndef FLEXILITE_DB_INIT_H
#define FLEXILITE_DB_INIT_H

#include "../definitions.h"

sqlite3 *db_open_in_memory();

int db_create_or_open(const char *zFile);

#endif //FLEXILITE_DB_INIT_H
