//
// Created by slanska on 2016-04-28.
//

#include <sqlite3ext.h>

int flexi_prop_merge_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
) {
    int result;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;

}

int flexi_prop_split_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
) {
    int result;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;

}

