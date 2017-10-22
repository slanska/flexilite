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

    void selfRegister();

public:
    explicit Database(uint64_t _dbHandle);
//    explicit Database(uintptr_t _dbHandle);

    explicit Database(std::string fileName) : Database(fileName, {}) {};

    explicit Database(std::string fileName, const DatabaseOptions &options);

    ~Database();

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
