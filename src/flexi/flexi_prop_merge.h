//
// Created by slanska on 2017-02-16.
//

#ifndef FLEXILITE_FLEXI_PROP_MERGE_H
#define FLEXILITE_FLEXI_PROP_MERGE_H

#include <sqlite3ext.h>

#ifdef __cplusplus
extern "C" {
#endif

int flexi_prop_merge_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

int flexi_prop_split_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

#ifdef __cplusplus
}
#endif

#endif //FLEXILITE_FLEXI_PROP_MERGE_H
