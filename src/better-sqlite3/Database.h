//
// Created by slanska on 2017-10-21.
//

#ifndef FLEXILITE_DATABASE_H
#define FLEXILITE_DATABASE_H

#include <string>
#include <dukglue.h>
#include "../project_defs.h"
#include "Statement.h"
#include "Transaction.h"

/*
 * Database open options
 */
struct DatabaseOptions
{
    bool memory = false;
    bool readonly = false;
    bool fileMustExist = false;
};

/*
 * Function register option
 */
struct RegistrationOptions
{
};

/*
 * Implements Database class in better-sqlite3
 */
class Database
{
private:
    DatabaseOptions openOptions = {};
    sqlite3 *db = nullptr;

    // All opened statements
    std::vector<Statement *> stmts = {};

    static int duk_constructor(duk_context* ctx);
    static int duk_destructor(duk_context* ctx);
    static int duk_prepare(duk_context* ctx);
    static int duk_exec(duk_context* ctx);
    static int duk_close(duk_context* ctx);
    static int duk_pragma(duk_context* ctx);
    static int duk_checkpoint(duk_context* ctx);
    static int duk_register(duk_context* ctx);
    static int duk_defaultSafeIntegers(duk_context* ctx);
    static int duk_memoryGetter(duk_context* ctx);
    static int duk_nameGetter(duk_context* ctx);
    static int duk_openGetter(duk_context* ctx);
    static int duk_inTransactionGetter(duk_context* ctx);
    static int duk_readonlyGetter(duk_context* ctx);

public:
    explicit Database(uint64_t _dbHandle);

    explicit Database(std::string fileName, const DatabaseOptions &options = {});

    ~Database();

    static void RegisterInDuktape(DukContext &ctx);

    bool getMemoryDB();

    bool getReadOnlyDB();

    bool isOpen();

    bool inTransaction();

    std::string getName();

    Statement *prepare(std::string source);

     Transaction &transaction(std::vector<std::string> &sources);

    Database *exec(std::string source);

    DukValue pragma(std::string source, bool simplify = false);

     Database *checkpoint(std::string databaseName = "");

     Database *close();

    /*
     * TODO:
     * register
     * defaultSafeIntegers
     */
};

#endif //FLEXILITE_DATABASE_H
