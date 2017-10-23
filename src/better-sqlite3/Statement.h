//
// Created by slanska on 2017-10-21.
//

#ifndef FLEXILITE_STATEMENT_H
#define FLEXILITE_STATEMENT_H

#include <string>
#include <cstdarg>
#include <dukglue.h>
#include <map>
#include "../project_defs.h"
#include "Util.h"

class Database;

class Statement
{
private:
    Database *db = nullptr;
    std::string sql{};
    sqlite3_stmt *stmt = nullptr;

    /*
     * Duktape C functions and properties
     */
    static int duk_constructor(duk_context*ctx);
    static int duk_destructor(duk_context*ctx);
    static int duk_safeIntegers(duk_context*ctx);
    static int duk_pluck(duk_context*ctx);
    static int duk_bind(duk_context*ctx);
    static int duk_get(duk_context*ctx);
    static int duk_all(duk_context*ctx);
    static int duk_each(duk_context*ctx);
//    static int duk_getDatabase(duk_context*ctx);
    static int duk_getSource(duk_context*ctx);
    static int duk_run(duk_context*ctx);
    static int duk_getReturnsData(duk_context*ctx);

public:
    explicit Statement(Database *_db, std::string _sql);

    explicit Statement(Database *_db, std::vector<std::string> _sources);

    ~Statement();

    static void RegisterInDuktape(duk_context* ctx);

    Database *getDatabase();

    std::string getSource();

    bool getReturnsData();

    RunResult *runSQL(std::vector<DukValue>);

    Statement *safeIntegers(bool toggleState = false);

    Statement *pluck(bool toggleState = false);

    Statement *bindParams(std::vector<DukValue> params);

    void forEachRow(std::vector<DukValue> params, DukValue callback);

    DukValue getFirstRow(std::vector<DukValue> params);

    DukValues * getNextRow(std::vector<DukValue> params);

};

#endif //FLEXILITE_STATEMENT_H
