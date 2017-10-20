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

void DBContext::CreateClass(std::string className, std::string classDefJson,
                            bool createVTable)
{

}

std::shared_ptr<ClassDef> DBContext::LoadClassDef(sqlite3_int64 classId)
{
    // TODO
    return nullptr;
}

std::shared_ptr<ClassDef> DBContext::LoadClassDef(std::string className)
{
    sqlite3_int64 classId = GetClassID(std::move(className));
    return LoadClassDef(classId);
}

sqlite3_int64 DBContext::GetClassID(std::string className)
{
    return 0;
}

void DBContext::CreateClassFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{
    // TODO Custom assert
    assert(argc == 2 || argc == 3);

    // 1st arg: class name
    std::string zClassName((char *) sqlite3_value_text(argv[0]));

    // 2nd arg: class definition, in JSON format
    std::string zClassDef((char *) sqlite3_value_text(argv[1]));

    // 3rd arg (optional): create virtual table
    bool bCreateVTable = false;
    if (argc == 3)
        bCreateVTable = sqlite3_value_int(argv[2]) != 0;

    CreateClass(zClassName, zClassDef, bCreateVTable);
}

void DBContext::InitDatabaseFunc(sqlite3_context *context, int argn, sqlite3_value **args)
{}

void DBContext::UsageFunc(sqlite3_context *context, int argn, sqlite3_value **args)
{}

void DBContext::AlterClassFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{}

void DBContext::DropClassFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{}

void DBContext::CreatePropFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{}

void DBContext::AlterPropFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{}

void DBContext::DropPropFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{}

void DBContext::RenameClassFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{}

void DBContext::RenamePropFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{}

void DBContext::MergePropFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{}

void DBContext::SplitPropFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{}

void DBContext::ObjectToPropsFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{}

void DBContext::PropsToObjectFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{}

void DBContext::PropToRefFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{}

void DBContext::RefToPropFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{}

void DBContext::ChangeObjectClassFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{}

void DBContext::SchemaFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{}

void DBContext::ConfigFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{}

void DBContext::StructuralSplitFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{}

void DBContext::StructuralMergeFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{}

void DBContext::RemoveDuplicatesFunc(sqlite3_context *context, int argc, sqlite3_value **argv)
{}

