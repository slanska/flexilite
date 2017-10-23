//
// Created by slanska on 2017-10-21.
//

#include "Database.h"

Database::Database(uint64_t _dbHandle) : db((sqlite3 *) _dbHandle)
//Database::Database(uintptr_t _dbHandle) : db((sqlite3 *) _dbHandle)
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

    int result = sqlite3_close(db);
    return this;
}

Database::~Database()
{
    // TODO invalidate in duktape
    close();
}

void Database::RegisterInDuktape(duk_context *ctx)
{
    dukglue_register_constructor<Database, uint64_t>(ctx, "Database");
    dukglue_register_method(ctx, &Database::pragma, "pragma");
    dukglue_register_method(ctx, &Database::prepare, "prepare");
    dukglue_register_method(ctx, &Database::close, "close");
    dukglue_register_method(ctx, &Database::exec, "exec");
}

