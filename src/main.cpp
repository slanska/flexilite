//
// Created by slanska on 2016-03-12.
//

#include <duk_config.h>
#include <dukglue.h>
#include <iostream>
#include "main.h"

#ifdef _WIN32
__declspec(dllexport)
#endif

bool is_mod_2(int a)
{
    return (a % 2) == 0;
}

void test_assert(bool value)
{
    assert(value);
}

void test_eval(duk_context *ctx, const char *code)
{
    if (duk_peval_string(ctx, code) != 0)
    {
        duk_get_prop_string(ctx, -1, "stack");
        std::cerr << "Error running '" << code << "':" << std::endl;
        std::cerr << duk_safe_to_string(ctx, -1) << std::endl;
        duk_pop(ctx);

        test_assert(false);
    }
}



extern "C" int sqlite3_extension_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
)
{
    SQLITE_EXTENSION_INIT2(pApi);

    /*
     * Duktape context holder, per thread
     */
    static class DukContext
    {
        duk_context *pCtx;
    public:

        explicit DukContext()
        {
            pCtx = duk_create_heap_default();

            std::cout << "##### DukContext: created" << std::endl;
            // Register SQLite functions
            dukglue_register_function(pCtx, is_mod_2, "is_mod_2");
            dukglue_register_function(pCtx, sqlite3_libversion, "sqlite3_libversion");


            test_eval(pCtx, "is_mod_2(5)");

            test_eval(pCtx, "sqlite3_libversion()");
            DukValue libVer = DukValue::take_from_stack(pCtx);
            std::cout << libVer.as_c_string() << std::endl;


            // Load .js
        }

        ~DukContext()
        {
            duk_destroy_heap(pCtx);
            std::cout << "##### DukContext: destroyed" << std::endl;
        }


        inline duk_context *getCtx()
        {
            return pCtx;
        }
    };

    thread_local auto pDukCtx = std::unique_ptr<DukContext>(new DukContext());

    int (*funcs[])(sqlite3 *, char **, const sqlite3_api_routines *) = {
            eval_func_init,
            fileio_func_init,
            regexp_func_init,
            totype_func_init,
            var_func_init,
            hash_func_init,
            memstat_func_init //,
            //            flexi_init
    };

    for (int idx = 0; idx < sizeof(funcs) / sizeof(funcs[0]); idx++)
    {
        int result = funcs[idx](db, pzErrMsg, pApi);
        if (result != SQLITE_OK)
            return result;
    }

    return SQLITE_OK;
}