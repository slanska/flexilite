//
// Created by slanska on 2017-02-08.
//

/*
 * flexi_class implementation of Flexilite class API
 */

#include "../project_defs.h"

#include <string.h>
#include <assert.h>
#include <ctype.h>

#include "../../lib/sqlite/sqlite3ext.h"

SQLITE_EXTENSION_INIT3

///
/// \param context
/// \param zClassName
/// \param zClassDef
/// \param bCreateVTable
/// \param pzError
/// \return
int flexi_class_create(sqlite3 *db,
                        // User data
                       void *pAux,
                       const char *zClassName,
                       const char *zClassDef,
                       int bCreateVTable,
                       char **pzError) {
    int result = SQLITE_OK;

    goto FINALLY;

    CATCH:
    return result;

    FINALLY:
    return result;

}

/// Creates Flexilite class
/// \param context
/// \param argc
/// \param argv
static void flexi_class_create_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
) {
    assert(argc == 2 || argc == 3);

    // 1st arg: class name
    const char *zClassName = (const char *) sqlite3_value_text(argv[0]);

    // 2nd arg: class definition, in JSON format
    const char *zClassDef = (const char *) sqlite3_value_text(argv[1]);

    // 3rd arg (optional): create virtual table
    int bCreateVTable = 0;
    if (argc == 3)
        bCreateVTable = sqlite3_value_int(argv[2]);

    char *zError = NULL;

    sqlite3 *db = sqlite3_context_db_handle(context);
    void *pAux = sqlite3_user_data(context);
    int result = flexi_class_create(db, pAux, zClassName, zClassDef, bCreateVTable, &zError);
    if (result != SQLITE_OK) {
        sqlite3_result_error(context, zError, result);
        sqlite3_free(zError);
    }
}

///
/// \param context
/// \param argc
/// \param argv
static void flexi_class_alter_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
) {
    // 1st arg: class name

    // 2nd arg: new class definition

}

///
/// \param context
/// \param argc
/// \param argv
static void flexi_class_drop_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
) {
    // 1st arg: class name


    // 2nd (optional): soft delete flag (if true, existing data will be preserved)
}

///
/// \param context
/// \param argc
/// \param argv
static void flexi_class_rename_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
) {
    // 1st arg: existing class name

    // 2nd arg: new class name
}

int flexi_class_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi) {
    int result = SQLITE_OK;
    CHECK_CALL(sqlite3_create_function_v2(db, "flexi_class_create",
                                          2, SQLITE_UTF8, NULL,
                                          flexi_class_create_func,
                                          0, 0, NULL));
    CHECK_CALL(sqlite3_create_function_v2(db, "flexi_class_create",
                                          3, SQLITE_UTF8, NULL,
                                          flexi_class_create_func,
                                          0, 0, NULL));
    CHECK_CALL(sqlite3_create_function_v2(db, "flexi_class_alter", 2,
                                          SQLITE_UTF8, NULL,
                                          flexi_class_alter_func, 0, 0, 0));
    CHECK_CALL(sqlite3_create_function_v2(db, "flexi_class_drop", 1,
                                          SQLITE_UTF8, NULL,
                                          flexi_class_alter_func, 0, 0, 0));
    CHECK_CALL(sqlite3_create_function_v2(db, "flexi_class_rename", 2,
                                          SQLITE_UTF8, NULL,
                                          flexi_class_alter_func, 0, 0, 0));
    goto FINALLY;

    CATCH:
    FINALLY:
    return result;
}



