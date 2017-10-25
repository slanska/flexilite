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
    Database::RegisterInDuktape(*this);

    // Statement
    Statement::RegisterInDuktape(*this);

    // TODO

    // If first run, compile JS bundle, and store bytecode

    // Load compiled bytecode into each context
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

int DukContext::PushObject()
{
    return 0;
}

void DukContext::PutFunctionList(duk_idx_t obj_idx, const duk_function_list_entry *funcs)
{

}

void DukContext::SetPrototype(duk_idx_t obj_idx)
{

}

void DukContext::PutGlobalString(const char *str)
{

}

void DukContext::PushBoolean(bool v)
{

}

int DukContext::test_result(int result)
{
    if (result < 0)
    {
        duk_get_prop_string(pCtx, -1, "stack");
        std::cerr << duk_safe_to_string(pCtx, -1) << std::endl;
        duk_pop(pCtx);

        assert(false);
    }

    return result;
}

void DukContext::defineProperty(int objIndex, const char *propName, duk_c_function Getter,
                                duk_c_function Setter)
{
    duk_uint_t flags = 0;
    duk_push_string(pCtx, propName);
    if (Getter != nullptr)
    {
        duk_push_c_function(pCtx, Getter, 0);
        flags |= DUK_DEFPROP_HAVE_GETTER;
    }
    if (Setter != nullptr)
    {
        duk_push_c_function(pCtx, Setter, 1);
        flags |= DUK_DEFPROP_HAVE_SETTER;
    }
    duk_def_prop(pCtx, objIndex, flags);
}
