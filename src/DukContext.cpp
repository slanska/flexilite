//
// Created by slanska on 2017-10-21.
//

#include "project_defs.h"
#include <duktape.h>
#include <iostream>
#include <dukglue.h>
#include "DukContext.h"
#include "better-sqlite3/Database.h"

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

/*
 * Duktape context implementation
 */
DukContext::DukContext()
{
    pCtx = duk_create_heap(duk_malloc, duk_realloc, duk_free, nullptr, nullptr);

    std::cout << "##### DukContext: created" << std::endl;

    // Database
    dukglue_register_constructor<Database, uint64_t>(pCtx, "Database");
//    dukglue_register_constructor<Database, std::string>(pCtx, "Database");
//    dukglue_register_constructor<Database, std::string, const DatabaseOptions &>(pCtx, "Database");
    dukglue_register_method(pCtx, &Database::pragma, "pragma");
    dukglue_register_method(pCtx, &Database::prepare, "prepare");
    dukglue_register_method(pCtx, &Database::close, "close");
    dukglue_register_method(pCtx, &Database::exec, "exec");

    // Statement
    dukglue_register_constructor<Statement, Database *, std::string>(pCtx, "Statement");
//    dukglue_register_constructor<Statement, Database *, std::vector<std::string>>(pCtx, "Statement");
    dukglue_register_method(pCtx, &Statement::all, "all");
    dukglue_register_method(pCtx, &Statement::get, "get");
    dukglue_register_method(pCtx, &Statement::bind, "bind");
    dukglue_register_method(pCtx, &Statement::each, "each");
    dukglue_register_method(pCtx, &Statement::run, "run");
    dukglue_register_method(pCtx, &Statement::pluck, "pluck");


    // Register SQLite functions
    //    dukglue_register_function(pCtx, is_mod_2, "is_mod_2");
    //    dukglue_register_function(pCtx, sqlite3_libversion, "sqlite3_libversion");
    //    dukglue_register_function(pCtx, sqlite3_memory_used, "sqlite3_memory_used");
    //    dukglue_register_function(pCtx, sqlite3_memory_highwater, "sqlite3_memory_highwater");
    //
    //    dukglue_register_function(pCtx, getVector, "getVector");
    //
    //    dukglue_register_constructor<Stmt, uint64_t, const char *>(pCtx, "Stmt");
    //    dukglue_register_method(pCtx, &Stmt::Prepare, "Prepare");
    //    dukglue_register_method(pCtx, &Stmt::Execute, "Execute");
    //
    //    test_eval(pCtx, "is_mod_2(5)");
    //
    //    test_eval(pCtx, "sqlite3_libversion()");
    //    DukValue libVer = DukValue::take_from_stack(pCtx);
    //    std::cout << "sqlite3_libversion: " << libVer.as_c_string() << std::endl;
    //
    //    test_eval(pCtx, "sqlite3_memory_used()");
    //    DukValue memUsed = DukValue::take_from_stack(pCtx);
    //    std::cout << "sqlite3_memory_used: " << memUsed.as_float() << std::endl;

    // Sqlite statement
    //    auto pDb = reinterpret_cast<uint64_t >  (db);
    //    dukglue_register_global(pDukCtx->getCtx(), pDb, "db");
    //
    //    std::string sql("    var st = new Stmt(db, 'select julianday();');"
    //                            "st.Prepare();"
    //                            "var dt = st.Execute();"
    //                            "delete st;"
    //                            "dt;"
    //    );
    //    test_eval(pDukCtx->getCtx(), sql.c_str());
    //    DukValue prepResult = DukValue::take_from_stack(pDukCtx->getCtx());
    //    std::cout << "exec result: " << prepResult.as_string() << std::endl;
    //
    //    // Vector
    //    std::string js = "var dd = getVector(['Привет ', 'Гномики ', ' Какдила?']);"
    //            "var total = 0;"
    //            "for (var i = 0; i < dd.length; i++) total += dd[i].length; total;";
    //    test_eval(pDukCtx->getCtx(), js.c_str());
    //    DukValue jsResult = DukValue::take_from_stack(pDukCtx->getCtx());
    //    std::cout << "exec result: " << jsResult.as_int() << std::endl;


    // Load .js
}

void DukContext::test_eval(const char *code)
{
    if (duk_peval_string(pCtx, code) != 0)
    {
        duk_get_prop_string(pCtx, -1, "stack");
        std::cerr << "Error running '" << code << "':" << std::endl;
        std::cerr << duk_safe_to_string(pCtx, -1) << std::endl;
        duk_pop(pCtx);

        assert(false);
    }
}


DukContext::~DukContext()
{
    duk_destroy_heap(pCtx);
    std::cout << "##### DukContext: destroyed" << std::endl;
}

thread_local auto pDukCtx = std::unique_ptr<DukContext>(new DukContext());
