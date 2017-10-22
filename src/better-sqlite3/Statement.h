//
// Created by slanska on 2017-10-21.
//

#ifndef FLEXILITE_STATEMENT_H
#define FLEXILITE_STATEMENT_H

#include <string>
#include <cstdarg>
#include <dukglue.h>
#include "../project_defs.h"
#include "Util.h"

class Database;

class Statement
{
private:
    Database *db = nullptr;
    std::string sql{};
    sqlite3_stmt *stmt = nullptr;
public:
    explicit Statement(Database *_db, std::string _sql);

    explicit Statement(Database *_db, std::vector<std::string> _sources);

    ~Statement();

    Database *getDatabase();

    std::string getSource();

    bool getReturnsData();

    RunResult *run(std::vector<DukValue>);

    Statement *safeIntegers(bool toggleState = false);

    Statement *pluck(bool toggleState = false);

    Statement *bind(std::vector<DukValue> params);

    void each(std::vector<DukValue> params, DukValue callback);

    std::vector<DukValue> get(std::vector<DukValue> params);

    std::vector<std::vector<DukValue>> all(std::vector<DukValue> params);

};

#endif //FLEXILITE_STATEMENT_H
