//
// Created by slanska on 2017-10-11.
//

#include "DBContext.h"

DBContext::DBContext(sqlite3 *_db) : db(_db)
{
    database = new SQLite::Database(_db);
}

std::shared_ptr<ClassDef> DBContext::getClassById(sqlite3_int64 classID)
{
    // TODO
    return nullptr;
}

std::shared_ptr<PropertyDef> DBContext::getPropertyById(sqlite3_int64 propertyID)
{
    // TODO
    return nullptr;
}

