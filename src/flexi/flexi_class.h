//
// Created by slanska on 2017-02-12.
//

#ifndef FLEXILITE_FLEXI_CLASS_H
#define FLEXILITE_FLEXI_CLASS_H

int flexi_class_create(sqlite3 *db,
        // User data
                       struct flexi_db_context *pCtx,
                       const char *zClassName,
                       const char *zClassDef,
                       int bCreateVTable,
                       char **pzError);

void flexi_class_create_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

void flexi_class_alter_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

void flexi_class_drop_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

int flexi_class_rename(struct flexi_db_context *pCtx, sqlite3_int64 iOldClassID, const char *zNewName);

void flexi_class_rename_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

#endif //FLEXILITE_FLEXI_CLASS_H
