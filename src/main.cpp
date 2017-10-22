//
// Created by slanska on 2016-03-12.
//

//#include <duk_config.h>
//#include <dukglue.h>
//#include <iostream>
#include "main.h"

//bool is_mod_2(int a)
//{
//    return (a % 2) == 0;
//}
//
//std::vector<std::string> getVector(std::vector<std::string> ss)
//{
//    return ss;
//}
//
//void test_assert(bool value)
//{
//    assert(value);
//}
//
//void test_eval(duk_context *ctx, const char *code)
//{
//    if (duk_peval_string(ctx, code) != 0)
//    {
//        duk_get_prop_string(ctx, -1, "stack");
//        std::cerr << "Error running '" << code << "':" << std::endl;
//        std::cerr << duk_safe_to_string(ctx, -1) << std::endl;
//        duk_pop(ctx);
//
//        test_assert(false);
//    }
//}
//
//class Stmt
//{
//public:
//    sqlite3 *db;            /* Database handle */
//    const char *zSql;       /* SQL statement, UTF-8 encoded */
//    sqlite3_stmt *pStmt = nullptr;  /* OUT: Statement handle */
//    const char *zTail = nullptr;     /* OUT: Pointer to unused portion of zSql */
//
//    explicit Stmt(uint64_t dbHandle, const char *_zSql) : db((sqlite3 *) dbHandle), zSql(_zSql)
//    {}
//
//    int Prepare()
//    {
//        int result = sqlite3_prepare(db, zSql, -1, &pStmt, &zTail);
//        return result;
//    }
//
//    std::string Execute()
//    {
//        int result = sqlite3_step(pStmt);
//        if (result == SQLITE_ROW)
//        {
//            auto v = (const char *) sqlite3_column_text(pStmt, 0);
//            std::string vv(v);
//            return vv;
//        }
//        return "";
//    }
//
//    ~Stmt()
//    {
//        std::cout << "Statement destroyed" << std::endl;
//        sqlite3_free((void *) zSql);
//        sqlite3_free((void *) zTail);
//        sqlite3_finalize(pStmt);
//    }
//};

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

    int (*funcs[])(sqlite3 *, char **, const sqlite3_api_routines *) = {
            eval_func_init,
            fileio_func_init,
            regexp_func_init,
            totype_func_init,
            var_func_init,
            hash_func_init,
            memstat_func_init,
            flexi_init
    };

    for (int idx = 0; idx < sizeof(funcs) / sizeof(funcs[0]); idx++)
    {
        int result = funcs[idx](db, pzErrMsg, pApi);
        if (result != SQLITE_OK)
            return result;
    }

    return SQLITE_OK;
}