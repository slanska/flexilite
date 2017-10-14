//
// Created by slanska on 2017-10-13.
//

#ifndef FLEXILITE_METADATAREF_H
#define FLEXILITE_METADATAREF_H

#include <string>
#include "../project_defs.h"
//#include "DBContext.h"

// Forward declarations
class DBContext;

class ClassDef;

class PropertyDef;

/*
 * Base reference type. Used for Symbol (Name) reference
 */
class SymbolRef
{
public:
    SymbolRef(DBContext &_context, sqlite3_int64 _id);

    SymbolRef(DBContext &_context, std::string &name);

    sqlite3_int64 id;

    // If id is not available, name must be supplied.
    std::string name;

    DBContext &context;

    sqlite3_int64 getIdByName();

};



class ClassRef : SymbolRef
{
public:
    std::shared_ptr<ClassDef> get() const;


    ClassRef(DBContext &_context, std::string &name) : SymbolRef(_context, name)
    {}

public:
    ClassRef(DBContext &_context, sqlite3_int64 _id) : SymbolRef(_context, _id)
    {}

};

class PropertyRef : SymbolRef
{
    std::shared_ptr<PropertyDef> get() const;

public:
    PropertyRef(DBContext &_context, sqlite3_int64 _id) : SymbolRef(_context, _id)
    {}

    PropertyRef(DBContext &_context, std::string &name) : SymbolRef(_context, name)
    {}
};

#endif //FLEXILITE_METADATAREF_H
