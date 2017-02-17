//
// Created by slanska on 2017-02-16.
//

#ifndef FLEXILITE_FLEXI_PROP_C_H
#define FLEXILITE_FLEXI_PROP_C_H

void flexi_prop_create_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

void flexi_prop_alter_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

void flexi_prop_drop_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

void flexi_prop_rename_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

#endif //FLEXILITE_FLEXI_PROP_C_H
