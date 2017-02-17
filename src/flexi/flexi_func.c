//
// Created by slanska on 2017-02-16.
//

/*
 * Implementation of proxy 'flexi' function
 */

#include "../project_defs.h"

SQLITE_EXTENSION_INIT3

static void flexi_func(sqlite3_context *context,
                       int argc,
                       sqlite3_value **argv) {

    const char * const zMethods[] =
            {
                    "create class",
                    "alter class",
                    "drop class",
                    "rename class",
                    "create property",
                    "alter property",
                    "drop property",
                    "rename property",
                    "help",
                    "init",
                    "merge property",
                    "split property",
                    "properties to object",
                    "object to properties"
            };
}

struct flexi_context {
// duktape context
// list of loaded classes
// current user
};

static void flexi_destroy(void *p) {
    struct flexi_context *pCtx = p;
}

int flexi_init(sqlite3 *db,
                        char **pzErrMsg,
                        const sqlite3_api_routines *pApi) {
    struct flexi_context *pCtx = NULL;
    pCtx = sqlite3_malloc(sizeof(*pCtx));
    memset(pCtx, 0, sizeof(*pCtx));
    int rc = sqlite3_create_function_v2(db, "flexi", 0, SQLITE_UTF8, pCtx,
                                        flexi_func, 0, 0, flexi_destroy);
    return rc;
}
