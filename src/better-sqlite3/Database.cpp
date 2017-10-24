//
// Created by slanska on 2017-10-21.
//

#include "Database.h"

Database::Database(uint64_t _dbHandle) : db((sqlite3 *) _dbHandle)
{
}

Database::Database(std::string fileName, const DatabaseOptions &options)
{
    int flags = 0;
    if (options.readonly)
        flags = SQLITE_OPEN_READONLY;
    else
        if (options.fileMustExist)
            flags = SQLITE_OPEN_READWRITE;
        else flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE;

    flags |= SQLITE_OPEN_SHAREDCACHE;
    if (options.memory)
        fileName = ":memory:";

    int rc = sqlite3_open_v2(fileName.c_str(), &db, flags, nullptr);
    if (rc != SQLITE_OK)
    {
        // TODO  get extended error
    }
}

bool Database::getMemoryDB()
{
    return openOptions.memory;
}

bool Database::getReadOnlyDB()
{
    return openOptions.readonly;
}

bool Database::isOpen()
{
    return db != nullptr;
}

bool Database::inTransaction()
{
    return false;
}

std::string Database::getName()
{
    return std::string();
}

Statement *Database::prepare(std::string source)
{
    Statement *result = new Statement(this, source);
    stmts.push_back(result);
    return result;
}

Transaction &Database::transaction(std::vector<std::string> &sources)
{
    Transaction t;
    return t;
}

Database *Database::exec(std::string source)
{
    return this;
}

DukValue Database::pragma(std::string source, bool simplify)
{
    return DukValue();
}

Database *Database::checkpoint(std::string databaseName)
{
    return this;
}

Database *Database::close()
{
    // TODO if own database, close it

    if (db != nullptr)
    {
        int result = sqlite3_close(db);
        db = nullptr;
    }
    return this;
}

Database::~Database()
{
    // TODO invalidate in duktape
    close();
}

void Database::RegisterInDuktape(DukContext &ctx)
{
    const duk_function_list_entry methods[] = {
            {"pragma",              duk_pragma,              -1},
            {"prepare",             duk_prepare,             1},
            {"close",               duk_close,               -1},
            {"exec",                duk_exec,                1},
            {"checkpoint",          duk_checkpoint,          -1},
            {"register",            duk_register,            -1},
            {"defaultSafeIntegers", duk_defaultSafeIntegers, -1},
            {nullptr,               nullptr,                 0}
    };

    // Statement function
    duk_push_c_function(ctx.getCtx(), &duk_constructor, -1);

    // Create a prototype with functions
    int protoIdx = duk_push_object(ctx.getCtx());
    duk_put_function_list(ctx.getCtx(), protoIdx, methods);

    // Register properties
    ctx.defineProperty(protoIdx, "memory", duk_memoryGetter);
    ctx.defineProperty(protoIdx, "open", duk_openGetter);
    ctx.defineProperty(protoIdx, "name", duk_nameGetter);
    ctx.defineProperty(protoIdx, "readonly", duk_readonlyGetter);
    ctx.defineProperty(protoIdx, "inTransaction", duk_inTransactionGetter);

    duk_set_prototype(ctx.getCtx(), protoIdx);

    // Now store the Point function as a global
    duk_put_global_string(ctx.getCtx(), "Database");

    // TODO Test
    duk_peval_string(ctx.getCtx(), "var db = new Database(':memory:');var st = db.prepare('select julianday();"
            "var row = st.get();row;');db.close();row;");

}

int Database::duk_constructor(duk_context *ctx)
{
    if (!duk_is_constructor_call(ctx))
    {
        return DUK_ERR_ERROR;
    }

    // Check number and types of parameters
    // Available options: 1 string parameter - file name
    //

    const char* fileName = duk_require_string(ctx, 0);
//    const char *zSql = duk_require_string(ctx, 1);

    duk_push_this(ctx);

    // Store object in internal property
    Database *self;
    self = new Database(fileName);
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

int Database::duk_destructor(duk_context *ctx)
{
    auto self = DukContext::getDukData<Database>(ctx);
    delete (self);
    return 0;
}

int Database::duk_prepare(duk_context *ctx)
{
    const char *sql = duk_require_string(ctx, 0);
    duk_push_global_object(ctx);
    duk_get_prop_string(ctx, -1, "Statement");
    duk_push_this(ctx);
    duk_push_string(ctx, sql);
    duk_new(ctx, 2);
    return 1;
}

int Database::duk_exec(duk_context *ctx)
{
    return 0;
}

int Database::duk_close(duk_context *ctx)
{
    return 0;
}

int Database::duk_pragma(duk_context *ctx)
{
    return 0;
}

int Database::duk_checkpoint(duk_context *ctx)
{
    return 0;
}

int Database::duk_register(duk_context *ctx)
{
    auto self = DukContext::getDukData<Database>(ctx);
    // Determine number and type of parameters
    // Create function proxy
    // Store proxy in map of functions

    // Compile function, load bytecode
    // Use function proxy as user data
    // TODO   sqlite3_create_function(self->db, );
    return 0;
}

int Database::duk_defaultSafeIntegers(duk_context *ctx)
{
    // no op
    // TODO Clear stack
//    duk_
    return 0;
}

int Database::duk_memoryGetter(duk_context *ctx)
{
    return 0;
}

int Database::duk_nameGetter(duk_context *ctx)
{
    return 0;
}

int Database::duk_openGetter(duk_context *ctx)
{
    return 0;
}

int Database::duk_inTransactionGetter(duk_context *ctx)
{
    return 0;
}

int Database::duk_readonlyGetter(duk_context *ctx)
{
    return 0;
}

