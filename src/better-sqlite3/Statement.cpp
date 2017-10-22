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

RunResult *Statement::run(std::vector<DukValue>)
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

Statement *Statement::bind(std::vector<DukValue> params)
{
    return this;
}

void Statement::each(std::vector<DukValue> params, DukValue callback)
{

}

std::vector<DukValue> Statement::get(std::vector<DukValue> params)
{
    return std::vector<DukValue>();
}

std::vector<std::vector<DukValue>> Statement::all(std::vector<DukValue> params)
{
    return std::vector<std::vector<DukValue>>();
}

