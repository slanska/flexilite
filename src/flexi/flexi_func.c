//
// Created by slanska on 2017-02-16.
//

/*
 * Implementation of proxy 'flexi' function
 */

#include "../project_defs.h"

#include "flexi_class.h"
#include "flexi_prop.h"
#include "flexi_prop_merge.h"

SQLITE_EXTENSION_INIT3

static void flexi_help_func(sqlite3_context *context,
                            int argc,
                            sqlite3_value **argv) {
    (void) argc;
    (void) argv;

    const char *zHelp = "Usage:"
            "   select flexi(<command>, <arguments>...)"
            "Commands: Arguments:"
            "   create class: class_name TEXT, class_definition JSON1, as_table BOOL"
            "   alter class: class_name TEXT, class_definition JSON1, as_table BOOL"
            "   drop class: class_name TEXT"
            "   rename class: old_class_name TEXT, new_class_name TEXT"
            "   create property: class_name TEXT, property_name TEXT, definition JSON1"
            "   alter property: class_name TEXT, property_name TEXT, definition JSON1"
            "   drop property: class_name TEXT, property_name TEXT"
            "   rename property: old_property_name TEXT, new_property_name TEXT"
            "   init";

    sqlite3_result_text(context, zHelp, -1, NULL);
}

static void flexi_init_func(sqlite3_context *context,
                            int argc,
                            sqlite3_value **argv) {
    (void) argc;
    (void) argv;

#ifdef RESOURCES_GENERATED

#include "../resources/dbschema.res.h"

    char *zSQL = sqlite3_malloc(sql_dbschema_sql_len + 1);
    memcpy(zSQL, sql_dbschema_sql, sql_dbschema_sql_len);
    zSQL[sql_dbschema_sql_len] = 0;
    sqlite3 *db = sqlite3_context_db_handle(context);
    char *zError = NULL;
    int result;
    CHECK_CALL(sqlite3_exec(db, zSQL, NULL, NULL, &zError));
    goto FINALLY;

    CATCH:
    sqlite3_result_error(context, zError, -1);

    FINALLY:
    sqlite3_free(zSQL);

#endif

}

static void flexi_func(sqlite3_context *context,
                       int argc,
                       sqlite3_value **argv) {

    if (argc == 0) {
        flexi_help_func(context, 0, NULL);
        return;
    }

    struct {
        const char *zMethod;

        void (*func)(sqlite3_context *, int, sqlite3_value **);

        int trn;
    } methods[] = {
            {"create class",    flexi_class_create_func, 1},
            {"alter class",         flexi_class_alter_func,  1},
            {"drop class",      flexi_class_drop_func,   1},
            {"rename class",    flexi_class_rename_func, 1},
            {"create property", flexi_prop_create_func,  1},
            {"alter property",  flexi_prop_alter_func,   1},
            {"drop property",   flexi_prop_drop_func,    1},
            {"rename property", flexi_prop_rename_func,  1},
            {"merge property",  flexi_prop_merge_func,   1},
            {"split property",  flexi_prop_split_func,   1},

            {"properties to object",  flexi_prop_to_obj_func,              1},
            {"object to properties",  flexi_obj_to_props_func,              1},
            {"property to reference", flexi_prop_to_ref_func,              1},
            {"reference to property", flexi_ref_to_prop_func,              1},
            {"change object class",   flexi_change_object_class,              1},

            {"init",            flexi_init_func,         1},
            {"help",            flexi_help_func,         0},
    };

    char *zMethodName = (char *) sqlite3_value_text(argv[0]);
    char *zError = NULL;
    int result;
    for (int ii = 0; ii < sizeof(methods) / sizeof(methods[0]); ii++) {
        if (sqlite3_stricmp(methods[ii].zMethod, zMethodName) == 0) {
            sqlite3 *db = NULL;
            if (methods[ii].trn) {
                db = sqlite3_context_db_handle(context);
                result = sqlite3_exec(db, "savepoint flexi1;", NULL, NULL, &zError);
                if (result) {
                    sqlite3_result_error(context, zError, -1);
                    return;
                }
            }
            methods[ii].func(context, argc - 1, &argv[1]);

            if (methods[ii].trn) {
                result = sqlite3_exec(db, "release flexi1;", NULL, NULL, &zError);
                if (result) {
                    sqlite3_result_error(context, zError, -1);
                }
            }
            return;
        }
    }

    zError = sqlite3_mprintf("Invalid method name: %s", zMethodName);
    sqlite3_result_error(context, zError, -1);
}

int flexi_data_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi,
        struct flexi_db_context *pEnv
);

void flexi_db_context_destroy(void *data) {
    flexi_db_context_deinit(data);
    sqlite3_free(data);
}

int flexi_init(sqlite3 *db,
               char **pzErrMsg,
               const sqlite3_api_routines *pApi) {
    struct flexi_db_context *pCtx;
    pCtx = sqlite3_malloc(sizeof(struct flexi_db_context));
    memset(pCtx, 0, sizeof(struct flexi_db_context));
    pCtx->db = db;

    int result;
    CHECK_CALL(sqlite3_create_function_v2(db, "flexi", 0, SQLITE_UTF8, pCtx,
                                          flexi_func, 0, 0, flexi_db_context_destroy));

    CHECK_CALL(flexi_data_init(db, pzErrMsg, pApi, pCtx));
    goto FINALLY;

    CATCH:
    flexi_db_context_destroy(pCtx);

    FINALLY:

    return result;
}
