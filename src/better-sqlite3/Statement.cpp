//
// Created by slanska on 2017-10-21.
//

#include "Statement.h"

Statement::Statement(Database *_db, std::string _sql) : db(_db)
{

}

Statement::Statement(Database *_db, std::vector<std::string> _sources) : db(_db)
{

}

Statement::~Statement()
{
    sqlite3_finalize(stmt);
}

Database *Statement::getDatabase()
{
    return db;
}

std::string Statement::getSource()
{
    return std::string();
}

bool Statement::getReturnsData()
{
    return false;
}

RunResult *Statement::runSQL(std::vector<DukValue>)
{
    return {};
}

Statement *Statement::safeIntegers(bool toggleState)
{
    return this;
}

Statement *Statement::pluck(bool toggleState)
{
    return this;
}

Statement *Statement::bindParams(std::vector<DukValue> params)
{
    return this;
}

void Statement::forEachRow(std::vector<DukValue> params, DukValue callback)
{

}

DukValue Statement::getFirstRow(std::vector<DukValue> params)
//std::vector<DukValue> Statement::getFirstRow(std::vector<DukValue> params)
{
    return DukValue();
}

void *Statement::getNextRow(std::vector<DukValue> params)
{
    //    throw std::invalid_argument("aaa");
    int ii = 0;
    //    for (auto v : params)
    //    {
    //        std::string k = std::to_string(++ii);
    //        result->set(k, v);
    //    }
    return nullptr;
}

int Statement::duk_constructor(duk_context *ctx)
{
    if (!duk_is_constructor_call(ctx))
    {
        return DUK_ERR_ERROR;
    }

    duk_require_object(ctx, 0);
    const char *zSql = duk_require_string(ctx, 1);

    duk_push_this(ctx);

    // Store object in internal property
    auto self = new Statement(nullptr, zSql);
    duk_push_pointer(ctx, self);
    duk_put_prop_string(ctx, -2, DUK_OBJECT_REF_PROP_NAME);

    // Store a boolean flag to mark the object as deleted because the destructor may be called several times
    duk_push_boolean(ctx, 0);
    duk_put_prop_string(ctx, -2, DUK_DELETED_PROP_NAME);

    // Store the function destructor
    duk_push_c_function(ctx, duk_destructor, 1);
    duk_set_finalizer(ctx, -2);

    return 0;
}

int Statement::duk_destructor(duk_context *ctx)
{
    auto self = DukContext::getDukData<Statement>(ctx);
    free(self);
    return 0;
}

int Statement::duk_safeIntegers(duk_context *ctx)
{
    duk_push_this(ctx);
    return 1;
}

int Statement::duk_pluck(duk_context *ctx)
{
    return 0;
}

int Statement::duk_bind(duk_context *ctx)
{
    return 0;
}

int Statement::duk_get(duk_context *ctx)
{
    return 0;
}

int Statement::duk_all(duk_context *ctx)
{
    return 0;
}

int Statement::duk_each(duk_context *ctx)
{
    return 0;
}

//int Statement::duk_getDatabase(duk_context *ctx)
//{
//    duk_push_this(ctx);
//    duk_get_prop_string(ctx, -1, "database");
//    duk_to_object(ctx, -1);
//    duk_pop_2(ctx);
//    return 0;
//}

int Statement::duk_getSource(duk_context *ctx)
{
    return 0;
}

int Statement::duk_run(duk_context *ctx)
{
    duk_push_this(ctx);


    return 0;
}

void Statement::RegisterInDuktape(DukContext &ctx)
{
    const duk_function_list_entry methods[] = {
            {"get",          duk_get,          -1},
            {"all",          duk_all,          -1},
            {"bind",         duk_bind,         -1},
            {"each",         duk_each,         -1},
            {"pluck",        duk_pluck,        -1},
            {"run",          duk_run,          -1},
            {"safeIntegers", duk_safeIntegers, -1},
            {nullptr,        nullptr,          0}
    };

    // Statement function
    duk_push_c_function(ctx.getCtx(), &duk_constructor, 2);

    // Create a prototype with functions
    int protoIdx = duk_push_object(ctx.getCtx());
    duk_put_function_list(ctx.getCtx(), protoIdx, methods);

    // Register properties
    //    DefineDuktapeProperty(ctx, obj, "database", duk_getDatabase);
    ctx.defineProperty(protoIdx, "source", duk_getSource);
    ctx.defineProperty(protoIdx, "returnsData", duk_getReturnsData);

    duk_set_prototype(ctx.getCtx(), protoIdx);

    // Now store the Point function as a global
    duk_put_global_string(ctx.getCtx(), "Statement");

    // TODO Test
//    duk_peval_string(ctx.getCtx(), "var st = new Statement(111, 'select julianday();');var row = st.get()");
}

int Statement::duk_getReturnsData(duk_context *ctx)
{
    auto dd = DukContext::getDukData<Statement>(ctx);
    bool returns_data = dd->stmt && sqlite3_stmt_readonly(dd->stmt)
                        && sqlite3_column_count(dd->stmt) >= 1;
    duk_push_boolean(ctx, (duk_bool_t) returns_data);
    return 1;
}

