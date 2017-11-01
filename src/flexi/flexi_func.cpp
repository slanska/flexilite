//
// Created by slanska on 2017-02-16.
//

/*
 * Implementation of proxy 'flexi' function
 */

extern "C"
{
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

#include <iostream>
#include <fstream>
#include <zconf.h>

#include "../project_defs.h"
#include "flexi_class.h"
//#include "DBContext.h"
//#include "../DukContext.h"
//#include "../better-sqlite3/Database.h"
#include "../util/Path.h"

extern "C"
{
LUALIB_API int luaopen_lsqlite3(lua_State *L);
int luaopen_cjson(lua_State *l);
}

static int flexi_help_func(sqlite3_context *context,
                           int argc,
                           sqlite3_value **argv)
{
    (void) argc;
    (void) argv;

    const char *zHelp = "Usage:"
            "   select flexi(<command>, <arguments>...)"
            "Commands: Arguments:"
            "   create class: class_name TEXT, class_definition JSON1, as_table BOOL"
            "   alter class: class_name TEXT, class_definition JSON1, as_table BOOL"
            "   drop class: class_name TEXT"
            "   rename class: old_class_name TEXT, new_class_name TEXT"
            "   create property: class_name TEXT, property_name TEXT, definition JSON1"
            "   alter property: class_name TEXT, property_name TEXT, definition JSON1"
            "   drop property: class_name TEXT, property_name TEXT"
            "   rename property: old_property_name TEXT, new_property_name TEXT"
            "   init";

    sqlite3_result_text(context, zHelp, -1, NULL);
    return SQLITE_OK;
}

static int flexi_init_func(sqlite3_context *context,
                           int argc,
                           sqlite3_value **argv)
{
    (void) argc;
    (void) argv;

#ifdef RESOURCES_GENERATED

#include "../resources/dbschema.res.h"

    char *zSQL = static_cast<char *>( sqlite3_malloc(sql_dbschema_sql_len + 1));
    memcpy(zSQL, sql_dbschema_sql, sql_dbschema_sql_len);
    zSQL[sql_dbschema_sql_len] = 0;
    sqlite3 *db = sqlite3_context_db_handle(context);
    char *zError = NULL;
    int result;
    CHECK_SQLITE(db, sqlite3_exec(db, zSQL, NULL, NULL, &zError));
    goto EXIT;

    ONERROR:
    sqlite3_result_error(context, zError, -1);

    EXIT:
    sqlite3_free(zSQL);
    return result;

#endif

}

//thread_local auto pDukCtx = std::unique_ptr<DukContext>(new DukContext());


/*
 * Central gateway to all Flexilite API
 */
static void flexi_func(sqlite3_context *context,
                       int argc,
                       sqlite3_value **argv)
{

    if (argc == 0)
    {
        flexi_help_func(context, 0, NULL);
        return;
    }

    /*
     * TODO description
     */
    struct
    {
        const char *zMethod;

        void (DBContext::*func)(sqlite3_context *, int, sqlite3_value **);

        bool noTrn;

        const char *zDescription;

        const char *zHelp;
    } methods[] = {
//            {"create class",          &DBContext::CreateClassFunc},
//            {"alter class",           &DBContext::AlterClassFunc},
//            {"drop class",            &DBContext::DropClassFunc},
//            {"rename class",          &DBContext::RenameClassFunc},
//            {"create property",       &DBContext::CreatePropFunc},
//            {"alter property",        &DBContext::AlterPropFunc},
//            {"drop property",         &DBContext::DropPropFunc},
//            {"rename property",       &DBContext::RenamePropFunc},
//            {"merge property",        &DBContext::MergePropFunc},
//            {"split property",        &DBContext::SplitPropFunc},
//
//            {"properties to object",  &DBContext::PropsToObjectFunc},
//            {"object to properties",  &DBContext::ObjectToPropsFunc},
//            {"property to reference", &DBContext::PropToRefFunc},
//            {"reference to property", &DBContext::RefToPropFunc},
//            {"change object class",   &DBContext::ChangeObjectClassFunc},
//
//            {"schema",                &DBContext::SchemaFunc},
//            {"config",                &DBContext::ConfigFunc},
//            {"structural merge",      &DBContext::StructuralMergeFunc},
//            {"structural split",      &DBContext::StructuralSplitFunc},
//            {"remove duplicates",     &DBContext::RemoveDuplicatesFunc},

            /* TODO
             * "structural merge" -- join 2+ objects to 1 object
             * "structural split" -- reverse operation to structural split
             * "remove duplicates" -- finds and merges duplicates by uid, code or name
             *
             */

//            {"init",                  &DBContext::InitDatabaseFunc},
//            {"help",                  &DBContext::UsageFunc, false},

            // TODO
        {"validate data",         nullptr},
    };


    char *zMethodName = (char *) sqlite3_value_text(argv[0]);
    char *zError = nullptr;
    int result = SQLITE_OK;
    return;

    for (int ii = 0; ii < sizeof(methods) / sizeof(methods[0]); ii++)
    {
        if (sqlite3_stricmp(methods[ii].zMethod, zMethodName) == 0)
        {
            sqlite3 *db = nullptr;

            if (!methods[ii].noTrn)
            {
                db = sqlite3_context_db_handle(context);

                result = sqlite3_exec(db, "savepoint flexi1;", NULL, NULL, &zError);
                if (result != SQLITE_OK)
                {
                    sqlite3_result_error(context, zError, -1);
                    return;
                }
            }

            // Check user_version
            std::shared_ptr<DBContext> pCtx;
            void *pData = sqlite3_user_data(context);
            memmove(&pCtx, pData, sizeof(pCtx));
            //            result = flexi_Context_checkMetaDataCache(pCtx);
            if (result == SQLITE_OK)
            {
                auto method = methods[ii].func;
                (*pCtx.*method)(context, argc - 1, &argv[1]);
            }

            if (!methods[ii].noTrn)
            {
                // Check if call finished with error
                // TODO
                if (result != SQLITE_OK)
                {
                    // Dump database
                    result = sqlite3_exec(db, "rollback to savepoint flexi1;", NULL, NULL, &zError);
                }
                else
                {
                    result = sqlite3_exec(db, "release flexi1;", NULL, NULL, &zError);
                }

                if (result != SQLITE_OK)
                {
                    sqlite3_result_error(context, zError, -1);
                }
            }

            if (result != SQLITE_OK)
            {
                sqlite3 *db = sqlite3_context_db_handle(context);
                zError = (char *) sqlite3_errmsg(db);
                sqlite3_result_error(context, zError, -1);
            }

            return;
        }
    }

    zError = sqlite3_mprintf("Invalid method name: %s", zMethodName);
    sqlite3_result_error(context, zError, -1);
}

int flexi_data_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi,
        DBContext *pCtx
);

//static void loadJsScript(const char *zFilePath)
//{
//    std::ifstream jsFile(zFilePath);
//    std::stringstream ss;
//    ss << jsFile.rdbuf();
//    std::string str = ss.str();
//    duk_peval_string(pDukCtx->getCtx(), str.c_str());
//}

extern "C" int flexi_init(sqlite3 *db,
                          char **pzErrMsg,
                          const sqlite3_api_routines *pApi)
{
    try
    {
        int result;
        sqlite3_stmt *pDummy = nullptr;

        lua_State *L = luaL_newstate();
        luaL_openlibs(L);
        luaopen_lsqlite3(L);
        luaopen_cjson(L);
        if (luaL_dostring(L, "require('socket')\n"
                "require(\"mobdebug\").loop()"))
        {
            printf("doString: %s\n", lua_tostring(L, -1));
        }
        printf("\nLua string\n");
        lua_pop(L, 1);
        char zCurrentDir[PATH_MAX + 1];
        char *zLuaSrc = nullptr;
        getcwd(zCurrentDir, PATH_MAX);
        Path_join(&zLuaSrc, zCurrentDir, "../../src_lua/DBContext.lua");
        if (luaL_dofile(L, "/Users/ruslanskorynin/Documents/Github/slanska/flexilite/src_lua/DBContext.lua"))
        {
            printf("doFile: %s\n", lua_tostring(L, -1));
        }
        printf("\nLua file\n");
        lua_pop(L, 1);
        lua_close(L);


        /*
         * TODO temp load from external file
         */
        //        loadJsScript("./duk-deps.js");
        //        loadJsScript("./flexi-duk.js");

        // Create new database instance in JavaScript
        //        auto dbAsInt = (uint64_t) db;
        //        std::ostringstream str;
        //        str << "var db = new Database(" << dbAsInt << "); "
        //                "Statement.prototype._all = function() { /*var r = [].slice.call(arguments);*/  return 'abc';}; "
        //                "var st = new Statement(db, 'select julianday();');"
        //                "st.getNextRow([1, '2', true, null]);";
        //        str << "var db = new Database(" << dbAsInt << ");"
        //                "var stmt = db.prepare('select julianday();');"
        //                "var row = stmt.get([]);";
        //        auto ss = str.str();

        //        auto database = new Database(dbAsInt);

        //        pDukCtx->test_eval(ss.c_str());
        //        dukglue_peval(pDukCtx->getCtx(), str.str().c_str());
        //        DukValue dbVal = DukValue::take_from_stack(pDukCtx->getCtx());

        CHECK_CALL(sqlite3_create_function_v2(db, "flexi", -1, SQLITE_UTF8,
                                              nullptr, // Use db context id
                                              flexi_func, nullptr, nullptr, nullptr));

        // Execute 'flexi_data' with dummy call to enable finalization
        //        CHECK_STMT_PREPARE(db, "select * from flexi_data();", &pDummy);
        //        result = sqlite3_step(pDummy);
        //        if (result != SQLITE_ROW && result != SQLITE_DONE)
        //            goto ONERROR;

        result = SQLITE_OK;
        goto EXIT;

        ONERROR:
        //        free(pDBCtx);

        EXIT:
        //        pCtx->nRefCount--;
        sqlite3_finalize(pDummy);
        return result;
    }
    catch (...)
    {
        return SQLITE_ERROR;
    }
}
