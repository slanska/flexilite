//
// Created by slanska on 2017-10-13.
//

#include "SymbolRef.h"
#include "DBContext.h"

sqlite3_int64 SymbolRef::getIdByName()
{
    // TODO
    return 0;
}

SymbolRef::SymbolRef(DBContext &_context, std::string &name)
        : name(name),
          context(_context)
{}

SymbolRef::SymbolRef(DBContext &_context,
                         sqlite3_int64 _id)
        : context(_context), id(_id)
{}

std::shared_ptr<ClassDef> ClassRef::get() const
{
    return context.getClassById(id);
}

std::shared_ptr<PropertyDef> PropertyRef::get() const
{
    return context.getPropertyById(id);
}
