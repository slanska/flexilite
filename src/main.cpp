//
// Created by slanska on 2016-03-12.
//

#include <duk_config.h>
#include <dukglue.h>
#include <iostream>
#include "main.h"

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

class Stmt
{
public:
    sqlite3 *db;            /* Database handle */
    const char *zSql;       /* SQL statement, UTF-8 encoded */
    sqlite3_stmt *pStmt = nullptr;  /* OUT: Statement handle */
    const char *zTail = nullptr;     /* OUT: Pointer to unused portion of zSql */

    explicit Stmt(uint64_t dbHandle, const char *_zSql) : db((sqlite3 *) dbHandle), zSql(_zSql)
    {}
    //    explicit Stmt(uintptr_t _db, const char* _zSql) : db((sqlite3 *) _db), zSql(_zSql)
    //    {}

    int Prepare()
    {
        int result = sqlite3_prepare(db, zSql, -1, &pStmt, &zTail);
        return result;
    }

    std::string Execute()
    {
        int result = sqlite3_step(pStmt);
        if (result == SQLITE_ROW)
        {
            auto v = (const char *) sqlite3_column_text(pStmt, 0);
            std::string vv(v);
            return vv;
        }
        return "";
    }

    ~Stmt()
    {
        std::cout << "Statement destroyed" << std::endl;
        sqlite3_free((void *) zSql);
        sqlite3_free((void *) zTail);
        sqlite3_finalize(pStmt);
    }
};

static void *duk_malloc(void *udata, duk_size_t size)
{
    return sqlite3_malloc((duk_size_t) size);
}

static void *duk_realloc(void *udata, void *ptr, duk_size_t size)
{
    return sqlite3_realloc(ptr, (duk_size_t) size);
}

static void duk_free(void *udata, void *ptr)
{
    sqlite3_free(ptr);
}

#ifdef _WIN32
__declspec(dllexport)
#endif
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
            pCtx = duk_create_heap(duk_malloc, duk_realloc,
                                   duk_free, nullptr, nullptr);
            //            pCtx = duk_create_heap_default();

            std::cout << "##### DukContext: created" << std::endl;
            // Register SQLite functions
            dukglue_register_function(pCtx, is_mod_2, "is_mod_2");
            dukglue_register_function(pCtx, sqlite3_libversion, "sqlite3_libversion");
            dukglue_register_function(pCtx, sqlite3_memory_used, "sqlite3_memory_used");
            dukglue_register_function(pCtx, sqlite3_memory_highwater, "sqlite3_memory_highwater");

            dukglue_register_constructor<Stmt, uint64_t, const char *>(pCtx, "Stmt");
            dukglue_register_method(pCtx, &Stmt::Prepare, "Prepare");
            dukglue_register_method(pCtx, &Stmt::Execute, "Execute");

            test_eval(pCtx, "is_mod_2(5)");

            test_eval(pCtx, "sqlite3_libversion()");
            DukValue libVer = DukValue::take_from_stack(pCtx);
            std::cout << "sqlite3_libversion: " << libVer.as_c_string() << std::endl;

            test_eval(pCtx, "sqlite3_memory_used()");
            DukValue memUsed = DukValue::take_from_stack(pCtx);
            std::cout << "sqlite3_memory_used: " << memUsed.as_float() << std::endl;


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


    auto pDb = reinterpret_cast<uint64_t >  (db);
    dukglue_register_global(pDukCtx->getCtx(), pDb, "db");

    std::string sql("    var st = new Stmt(db, 'select julianday();');"
                            "st.Prepare();"
                            "var dt = st.Execute();"
                            "delete st;"
                            "dt;"
    );
    test_eval(pDukCtx->getCtx(), sql.c_str());
    DukValue prepResult = DukValue::take_from_stack(pDukCtx->getCtx());
    std::cout << "exec result: " << prepResult.as_string() << std::endl;

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