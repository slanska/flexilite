//
// Created by slanska on 2017-02-12.
//

#ifndef FLEXILITE_FLEXI_CLASS_H
#define FLEXILITE_FLEXI_CLASS_H

int flexi_class_create(struct flexi_db_context *pCtx, const char *zClassName, const char *zClassDef, int bCreateVTable,
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

void flexi_change_object_class(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

void flexi_prop_to_obj_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);


/*
 * Internally used function to apply schema changes to the class that does not
 * have any data (so no data refactoring would be required)
 */
int flexi_alter_class_wo_data(struct flexi_db_context *pCtx, sqlite3_int64 lClassID,
                              const char *zNewClassDef, char **pzErr);

///
/// \param pCtx
/// \param zClassName
/// \param zNewClassDefJson
/// \param bCreateVTable
/// \param pzError
/// \return
int flexi_class_alter(struct flexi_db_context *pCtx,
                      const char *zClassName,
                      const char *zNewClassDefJson,
                      int bCreateVTable,
                      const char **pzError
);

///
/// \param pCtx
/// \param lClassID
/// \param softDelete
/// \return
int flexi_class_drop(struct flexi_db_context *pCtx, sqlite3_int64 lClassID, int softDelete, const char **pzError);

void flexi_props_to_obj_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

void flexi_obj_to_props_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

#endif //FLEXILITE_FLEXI_CLASS_H
