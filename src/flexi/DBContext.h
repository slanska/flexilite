//
// Created by slanska on 2017-10-11.
//

#ifndef FLEXILITE_DBCONTEXT_H
#define FLEXILITE_DBCONTEXT_H

#include <string>
#include <map>
#include <unordered_map>
#include "../project_defs.h"
#include "ClassDef.h"
#include "../sqlite/Database.h"

class ClassDef;

class DBContext
{
    SQLite::Database *database = nullptr;

public:
    explicit DBContext(sqlite3 *_db);

    /*
   * Associated database connection
   */
    sqlite3 *db;

    sqlite3_stmt *pStmts[STMT_DEL_FTS + 1] = {};

    /*
     * In-memory database used for certain operations, e.g. MATCH function on non-FTS indexed columns.
     * Lazy-opened and initialized on demand, on first attempt to use it.
     */
    sqlite3 *pMemDB = nullptr;

    /*
     * Prepared SQL statement used by MATCH function on non-FTS indexed columns to insert temporary rows
     * into full text index table
     */
    sqlite3_stmt *pMatchFuncInsStmt = nullptr;

    /*
     * Prepared SQL statement used by MATCH function on non-FTS indexed columns to select temporary rows
     * from full text index table
     */
    sqlite3_stmt *pMatchFuncSelStmt = nullptr;

    /*
     * Info on current user
     */
    flexi_UserInfo_t *pCurrentUser = nullptr;

    /*
     * Duktape context. Created on demand
     */
    //    duk_context *pDuk = nullptr;

    /*
     * Hash of loaded class definitions (by current names)
     */
    //    Hash classDefsByName;

    std::unordered_map<std::string, std::shared_ptr<ClassDef>> classDefsByName = {};

    // TODO Init and use
    Hash classDefsById = {};

    /*
     * Last error
     */
    char *zLastErrorMessage = nullptr;
    int iLastErrorCode = 0;

    sqlite3_int64 lUserVersion = 0;

    /*
     * Number of open vtables.
     */
    sqlite3_int64 nRefCount = 0;

    enum FLEXI_DATA_LOAD_ROW_MODES eLoadRowMode = LOAD_ROW_MODE_ROW_PER_OBJECT;

    /*
     * RB tree of existing ref-values rows processed during current request (flexi and flexi_data calls)
     * Tree is ordered by objectID, propertyID, property index
     * Items in tree are flexi_RefValue_t
     * Cache gets cleared on every exit
     */

    // TODO use map/unordered_map
    struct RBTree refValueCache = {};

public:
    std::shared_ptr<ClassDef> getClassById(sqlite3_int64 classID);

    std::shared_ptr<PropertyDef> getPropertyById(sqlite3_int64 propertyID);

    void CreateClass(std::string className, std::string classDefJson,
                     bool createVTable);
    std::shared_ptr<ClassDef> LoadClassDef(sqlite3_int64 classId);
    std::shared_ptr<ClassDef> LoadClassDef(std::string className);

    // 'flexi' sqlite sub-functions
    void CreateClassFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void InitDatabaseFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void UsageFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void AlterClassFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void DropClassFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void CreatePropFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void AlterPropFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void DropPropFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void RenameClassFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void RenamePropFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void MergePropFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void SplitPropFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void ObjectToPropsFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void PropsToObjectFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void PropToRefFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void RefToPropFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void ChangeObjectClassFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void SchemaFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void ConfigFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void StructuralSplitFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void StructuralMergeFunc(sqlite3_context*context, int argc, sqlite3_value** argv);
    void RemoveDuplicatesFunc(sqlite3_context*context, int argc, sqlite3_value** argv);

    sqlite3_int64 GetClassID(std::string className);
};

#endif //FLEXILITE_DBCONTEXT_H
