//
// Created by slanska on 2017-02-08.
//

/*
 * flexi_class implementation of Flexilite class API
 */

#include "flexi_class.h"
#include "../typings/DBDefinitions.h"

/*
 * Create new class record in the database
 */
static int _create_class_record(struct flexi_db_context *pCtx, const char *zClassName, sqlite3_int64 *lClassID)
{
    int result;
    if (!pCtx->pStmts[STMT_INS_CLS])
    {
        CHECK_CALL(sqlite3_prepare_v2(pCtx->db,
                                      "insert into [.classes] (NameID) values (:1);",
                                      -1, &pCtx->pStmts[STMT_INS_CLS],
                                      NULL));
    }
    CHECK_CALL(sqlite3_reset(pCtx->pStmts[STMT_INS_CLS]));
    sqlite3_int64 lClassNameID;
    CHECK_CALL(db_insert_name(pCtx, zClassName, &lClassNameID));
    CHECK_CALL(sqlite3_bind_int64(pCtx->pStmts[STMT_INS_CLS], 0, lClassNameID));
    CHECK_STMT(sqlite3_step(pCtx->pStmts[STMT_INS_CLS]));
    if (result != SQLITE_DONE)
        goto CATCH;

    CHECK_CALL(db_get_class_id_by_name(pCtx, zClassName, lClassID));

    goto FINALLY;

    CATCH:

    FINALLY:
    return result;
}

static int _parseSpecialProperties()
{
    int result = SQLITE_OK;

    const char *zSpecialProps = "select "
            "json_extract(:1, '$.specialProperties.uid') as uid,"; // 0
    "json_extract(:1, '$.specialProperties.name') as name,"; // 1
    "json_extract(:1, '$.specialProperties.description') as description,"; // 2
    "json_extract(:1, '$.specialProperties.code') as code,"; // 3
    "json_extract(:1, '$.specialProperties.nonUniqueId') as nonUniqueId,"; // 4
    "json_extract(:1, '$.specialProperties.createTime') as createTime,"; // 5
    "json_extract(:1, '$.specialProperties.updateTime') as updateTime,"; // 6
    "json_extract(:1, '$.specialProperties.autoUuid') as autoUuid,"; // 7
    "json_extract(:1, '$.specialProperties.autoShortId') as autoShortId "; // 8

    return result;
}

static int _parseRangeProperties()
{
    int result = SQLITE_OK;

    // Range indexing
    // $.rangeIndexing
    const char *zRangeProps = "select "
            "json_extract(:1, '$.rangeIndexing.A0') as A0," // 0
            "json_extract(:1, '$.rangeIndexing.A1') as A1," // 0
            "json_extract(:1, '$.rangeIndexing.B0') as B0," // 0
            "json_extract(:1, '$.rangeIndexing.B1') as B1," // 0
            "json_extract(:1, '$.rangeIndexing.C0') as C0," // 0
            "json_extract(:1, '$.rangeIndexing.C1') as C1," // 0
            "json_extract(:1, '$.rangeIndexing.D0') as D0," // 0
            "json_extract(:1, '$.rangeIndexing.D1') as D1," // 0
            "json_extract(:1, '$.rangeIndexing.E0') as E0," // 0
            "json_extract(:1, '$.rangeIndexing.E1') as E1"; // 0

    return result;
}

static int _parseFullTextProperties()
{
    int result = SQLITE_OK;

    // Full text indexing
    const char *zFtsProps = "select "
            "json_extract(:1, '$.fullTextIndexing.X1') as X1," // 0
            "json_extract(:1, '$.fullTextIndexing.X2') as X2," // 0
            "json_extract(:1, '$.fullTextIndexing.X3') as X3," // 0
            "json_extract(:1, '$.fullTextIndexing.X4') as X4," // 0
            "json_extract(:1, '$.fullTextIndexing.X5') as X5"; // 0

    return result;
}

static int _parseMixins()
{
    int result = SQLITE_OK;
    return result;
}

static int _parseProperties()
{
    int result = SQLITE_OK;
    return result;
}

/*
 *
 */
struct flexi_class_def *flexi_class_def_new(struct flexi_db_context *pCtx)
{
    struct flexi_class_def *result = sqlite3_malloc(sizeof(struct flexi_class_def));
    if (!result)
        return result;
    memset(result, 0, sizeof(*result));

    result->pCtx = pCtx;
    HashTable_init(&result->propMap, (void *) flexi_prop_def_free);

    return result;
}

/// @brief Creates a new Flexilite class, based on name and JSON definition.
/// Class must not exist
/// @param zClassName
/// @param zClassDef
/// @param bCreateVTable
/// @param pzError
/// @return
int flexi_class_create(struct flexi_db_context *pCtx, const char *zClassName,
                       const char *zClassDef, int bCreateVTable,
                       const char **pzError)
{
    int result;

    // Disposable resources
    sqlite3_stmt *pExtractProps = NULL;
    sqlite3_stmt *pInsClsStmt = NULL;
    sqlite3_stmt *pInsPropStmt = NULL;
    sqlite3_stmt *pUpdClsStmt = NULL;
    unsigned char *zPropDefJSON = NULL;

    // Check if class does not exist yet
    sqlite3_int64 lClassID;
    CHECK_CALL(db_get_class_id_by_name(pCtx, zClassName, &lClassID));
    if (lClassID > 0)
    {
        result = SQLITE_ERROR;
        *pzError = sqlite3_mprintf("Class [%s] already exists", zClassName);
        goto CATCH;
    }

    if (!db_validate_name((const unsigned char *) zClassName))
    {
        result = SQLITE_ERROR;

        goto CATCH;
    }

    CHECK_CALL(_create_class_record(pCtx, zClassName, &lClassID));

    CHECK_CALL(flexi_alter_new_class(pCtx, lClassID, zClassDef, pzError));


    // TODO

    char *sbClassDefJSON = sqlite3_mprintf("{\"properties\":{");

    struct flexi_prop_def dProp;
    memset(&dProp, 0, sizeof(dProp));

    sqlite3_int64 lClassNameID;
    CHECK_CALL(db_insert_name(pCtx, zClassName, &lClassNameID));

    // insert into .classes
    {
        const char *zInsClsSQL = "insert into [.classes] (NameID) values (:1);";

        CHECK_CALL(sqlite3_prepare_v2(pCtx->db, zInsClsSQL, -1, &pInsClsStmt, NULL));
        sqlite3_bind_int64(pInsClsStmt, 1, lClassNameID);
        int stepResult = sqlite3_step(pInsClsStmt);
        if (stepResult != SQLITE_DONE)
        {
            result = stepResult;
            goto CATCH;
        }
    }

    sqlite3_int64 iClassID;
    {
        sqlite3_stmt *p = pCtx->pStmts[STMT_SEL_CLS_BY_NAME];
        assert(p);
        sqlite3_reset(p);
        sqlite3_bind_text(p, 1, zClassName, -1, NULL);
        int stepRes = sqlite3_step(p);
        if (stepRes != SQLITE_ROW)
        {
            result = stepRes;
            goto CATCH;
        }

        iClassID = sqlite3_column_int64(p, 0);
    }

    int xCtloMask = 0;

    const char *zInsPropSQL = "insert into [flexi_prop] (NameID, ClassID, ctlv, ctlvPlan)"
            " values (:1, :2, :3, :4);";
    CHECK_CALL(sqlite3_prepare_v2(pCtx->db, zInsPropSQL, -1, &pInsPropStmt, NULL));

    // Prepare JSON processing
    const char *zExtractPropSQL = "select "
            "coalesce(json_extract(value, '$.index'), 'none') as indexed," // 0
            //    subType // 1
            //    minOccurences // 2
            //    maxOccurences // 3
            "coalesce(json_extract(value, '$.rules.type'), 'text') as type," // 4
            "key as prop_name," // 5
            "value as prop_def," // 6 - Original property definition JSON
            "coalesce(json_extract(value, '$.noTrackChanges'), 0) as indexed," // 7
            //    enumDef
            //    refDef
            //    $renameTo
            //    $drop
            //    rules.maxLength
            //    rules.minValue
            //    rules.maxValue
            //    rules.regex
            " from json_each(:1, '$.properties');";

    // Need to remove leading and trailing quotes
    int iJSONLen = (int) strlen(zClassDef);
    CHECK_CALL(sqlite3_prepare_v2(pCtx->db, zExtractPropSQL, -1, &pExtractProps, NULL));
    CHECK_CALL(sqlite3_bind_text(pExtractProps, 1, zClassDef + sizeof(char), iJSONLen - 2, NULL));

    int iPropCnt = 0;

    // Load property definitions from JSON
    while (1)
    {
        int iStep = sqlite3_step(pExtractProps);
        if (iStep == SQLITE_DONE)
            break;

        if (iStep != SQLITE_ROW)
        {
            result = iStep;
            goto CATCH;
        }

        memset(&dProp, 0, sizeof(dProp));
        dProp.bIndexed = (char) sqlite3_column_int(pExtractProps, 0);
        dProp.bUnique = (char) sqlite3_column_int(pExtractProps, 1);
        dProp.bFullTextIndex = (char) sqlite3_column_int(pExtractProps, 2);
        dProp.xRole = (short int) sqlite3_column_int(pExtractProps, 3);
        dProp.type = sqlite3_column_int(pExtractProps, 4);

        sqlite3_free((void *) zPropDefJSON);
        //        sqlite3_free(dProp.zName);
        dProp.name.name = sqlite3_malloc(sqlite3_column_bytes(pExtractProps, 5) + 1);
        zPropDefJSON = sqlite3_malloc(sqlite3_column_bytes(pExtractProps, 6) + 1);
        strcpy(dProp.name.name, (const char *) sqlite3_column_text(pExtractProps, 5));
        strcpy((char *) zPropDefJSON, (const char *) sqlite3_column_text(pExtractProps, 6));

        // Property control flags which regulate actual indexing and other settings
        int xCtlv = 0;

        // Planned (postponed for future) property control flags which will be applied later
        // when enough statistics accumulated about best index strategy.
        // Typically, this will happen when database size reaches few megabytes and 1K-5K records
        // On smaller databases there is no real point to apply indexing to the full extent
        // Plus, in the database schema lifetime initial period is usually associated with heavy refactoring
        // and data restructuring.
        // Taking into account these 2 considerations, we will remember user settings for desired indexing
        // (in ctlvPlan) but currently apply only settings for unique values (as it is mostly constraint, rather
        // than indexing)
        int xCtlvPlan = 0;

        switch (dProp.type)
        {
            // These property types can be searched by range, can be indexed and can be unique
            case PROP_TYPE_DECIMAL:
            case PROP_TYPE_NUMBER:
            case PROP_TYPE_DATETIME:
            case PROP_TYPE_INTEGER:

                // These property types can be indexed
            case PROP_TYPE_BINARY:
            case PROP_TYPE_NAME:
            case PROP_TYPE_ENUM:
            case PROP_TYPE_UUID:
                if (dProp.bUnique || (dProp.xRole & PROP_ROLE_ID) || (dProp.xRole & PROP_ROLE_NAME))
                {
                    xCtlv |= CTLV_UNIQUE_INDEX;
                    xCtlvPlan |= CTLV_UNIQUE_INDEX;
                }
                // Note: no break here;

            case PROP_TYPE_TEXT:
                if (dProp.bIndexed && dProp.maxLength <= 30)
                    xCtlvPlan |= CTLV_INDEX;
                if (dProp.bFullTextIndex)
                    xCtlvPlan |= CTLV_FULL_TEXT_INDEX;

                break;
        }

        sqlite3_int64 lPropNameID;
        CHECK_CALL(db_insert_name(pCtx, dProp.name.name, &lPropNameID));

        {
            sqlite3_reset(pInsPropStmt);
            sqlite3_bind_int64(pInsPropStmt, 1, lPropNameID);
            sqlite3_bind_int64(pInsPropStmt, 2, iClassID);
            sqlite3_bind_int(pInsPropStmt, 3, xCtlv);
            sqlite3_bind_int(pInsPropStmt, 4, xCtlvPlan);
            int stepResult = sqlite3_step(pInsPropStmt);
            if (stepResult != SQLITE_DONE)
            {
                result = stepResult;
                goto CATCH;
            }
        }

        // Get new property ID
        sqlite3_int64 iPropID;
        CHECK_CALL(db_get_prop_id_by_class_and_name(pCtx, iClassID, lPropNameID, &iPropID));
        if (iPropCnt != 0)
        {
            void *pTmp = sbClassDefJSON;
            sbClassDefJSON = sqlite3_mprintf("%s,", pTmp);
            sqlite3_free(pTmp);
        }

        {
            void *pTmp = sbClassDefJSON;
            sbClassDefJSON = sqlite3_mprintf("%s\"%lld\":%s", pTmp, iPropID, zPropDefJSON);
            sqlite3_free(pTmp);
        }

        iPropCnt++;
    }

    {
        void *pTmp = sbClassDefJSON;
        sbClassDefJSON = sqlite3_mprintf("%s}}", pTmp);
        sqlite3_free(pTmp);
    }

    // Update class with new JSON data
    const char *zUpdClsSQL = "update [.classes] set Data = :1, ctloMask= :2 where ClassID = :3";
    CHECK_CALL(sqlite3_prepare_v2(pCtx->db, zUpdClsSQL, -1, &pUpdClsStmt, NULL));
    sqlite3_bind_text(pUpdClsStmt, 1, sbClassDefJSON, (int) strlen(sbClassDefJSON), NULL);
    sqlite3_bind_int(pUpdClsStmt, 2, xCtloMask);
    sqlite3_bind_int64(pUpdClsStmt, 3, iClassID);
    int updResult = sqlite3_step(pUpdClsStmt);
    if (updResult != SQLITE_DONE)
    {
        result = updResult;
        goto CATCH;
    }

    // TODO
    //    CHECK_CALL(flexi_class_def_load(db, pAux, zClassName, ppVTab, pzErr));

    result = SQLITE_OK;

    goto FINALLY;

    CATCH:
    // Release resources because of errors (catch)
    printf("%s", sqlite3_errmsg(pCtx->db));

    FINALLY:

    sqlite3_free((void *) zPropDefJSON);
    sqlite3_free(dProp.name.name);

    if (pExtractProps)
        sqlite3_finalize(pExtractProps);
    if (pInsClsStmt)
        sqlite3_finalize(pInsClsStmt);
    if (pUpdClsStmt)
        sqlite3_finalize(pUpdClsStmt);
    if (pInsPropStmt)
        sqlite3_finalize(pInsPropStmt);

    sqlite3_free(sbClassDefJSON);

    return result;

    /*
     * TODO
     * jsonParse
     * jsonLookup
     * jsonRenderNode
     * jsonReturnJson (sets sqlite3_result_*)
     *
     * jsonParseReset
     */
}

/// @brief Implementation of SQLite custom function to create a new Flexilite class
/// @param context
/// @param argc
/// @param argv
void flexi_class_create_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    assert(argc == 2 || argc == 3);

    // 1st arg: class name
    const char *zClassName = (const char *) sqlite3_value_text(argv[0]);

    // 2nd arg: class definition, in JSON format
    const char *zClassDef = (const char *) sqlite3_value_text(argv[1]);

    // 3rd arg (optional): create virtual table
    int bCreateVTable = 0;
    if (argc == 3)
        bCreateVTable = sqlite3_value_int(argv[2]);

    const char *zError = NULL;

    sqlite3 *db = sqlite3_context_db_handle(context);

    int result;
    char *zSQL = NULL;
    if (bCreateVTable)
    {
        zSQL = sqlite3_mprintf("create virtual table [%s] using flexi ('%s')", zClassName, zClassDef);
        CHECK_CALL(sqlite3_exec(db, zSQL, NULL, NULL, (char **) &zError));
    }
    else
    {
        void *pCtx = sqlite3_user_data(context);
        CHECK_CALL(flexi_class_create(pCtx, zClassName, zClassDef, bCreateVTable, &zError));
    }

    goto FINALLY;

    CATCH:
    if (zError)
    {
        sqlite3_result_error(context, zError, result);
        sqlite3_free((void *) zError);
    }

    FINALLY:
    sqlite3_free(zSQL);
}

///
/// \param context
/// \param argc
/// \param argv
void flexi_class_alter_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    assert(argc == 2);

    int result;
    // 1st arg: class name
    char *zClassName = (char *) sqlite3_value_text(argv[0]);

    // 2nd arg: new class definition
    char *zNewClassDef = (char *) sqlite3_value_text(argv[1]);

    // 3rd optional argument - create virtual table for class
    int bCreateVTable = 0;
    if (argc == 3)
        bCreateVTable = sqlite3_value_int(argv[2]);

    const char *zError = NULL;

    struct flexi_db_context *pCtx = sqlite3_user_data(context);
    CHECK_CALL(flexi_class_alter(pCtx, zClassName, zNewClassDef, bCreateVTable, &zError));

    goto FINALLY;

    CATCH:
    if (zError)
        sqlite3_result_error(context, zError, -1);

    FINALLY:
    {};
}

int flexi_class_drop(struct flexi_db_context *pCtx, sqlite3_int64 lClassID, int softDelete,
                     const char **pzError)
{
    // TODO

    return 0;

    /*
     * When softDelete, data in .objects and .ref-values are preserved but moved to the system Object class
     * indexes, full text data and range data will be deleted
     */

    // .objects

    // .full_text_data

    // .range_data

    // .ref-values

    // flexi_prop

    // .classes
}

///
/// \param context
/// \param argc
/// \param argv
void flexi_class_drop_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    assert(argc == 2 || argc == 1);

    int result;
    const char *zError = NULL;

    // 1st arg: class name
    char *zClassName = (char *) sqlite3_value_text(argv[0]);

    // 2nd (optional): soft delete flag (if true, existing data will be preserved)
    int softDel = 0;
    if (argc == 2)
        softDel = sqlite3_value_int(argv[1]);

    sqlite3_int64 lClassID;
    struct flexi_db_context *pCtx = sqlite3_user_data(context);
    CHECK_CALL(db_get_class_id_by_name(pCtx, zClassName, &lClassID));

    CHECK_CALL(flexi_class_drop(pCtx, lClassID, softDel, &zError));
    goto FINALLY;

    CATCH:
    if (!zError)
        sqlite3_result_error(context, zError, -1);
    else
        if (result != SQLITE_OK)
            sqlite3_result_error(context, sqlite3_errstr(result), -1);

    FINALLY:
    {};
}

int flexi_class_rename(struct flexi_db_context *pCtx, sqlite3_int64 iOldClassID, const char *zNewName)
{
    assert(pCtx && pCtx->db);

    int result;

    sqlite3_int64 lNewNameID;
    CHECK_CALL(db_insert_name(pCtx, zNewName, &lNewNameID));

    // TODO Move to prepared statements
    if (!pCtx->pStmts[STMT_CLS_RENAME])
    {
        const char *zErrMsg;
        sqlite3_stmt *pStmt;
        CHECK_CALL(sqlite3_prepare_v2(pCtx->db, "update [.classes] set NameID = :1 "
                "where ClassID = :2;", -1, &pCtx->pStmts[STMT_CLS_RENAME], &zErrMsg));
    }
    CHECK_CALL(sqlite3_reset(pCtx->pStmts[STMT_CLS_RENAME]));
    sqlite3_bind_int64(pCtx->pStmts[STMT_CLS_RENAME], 1, lNewNameID);
    sqlite3_bind_int64(pCtx->pStmts[STMT_CLS_RENAME], 2, iOldClassID);
    CHECK_STMT(sqlite3_step(pCtx->pStmts[STMT_CLS_RENAME]));
    result = SQLITE_OK;
    goto FINALLY;

    CATCH:

    FINALLY:

    return result;
}

///
/// \param context
/// \param argc
/// \param argv
void flexi_class_rename_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    assert(argc == 2);

    char *zErr = NULL;

    // 1st arg: existing class name
    char *zOldClassName = (char *) sqlite3_value_text(argv[0]);

    // 2nd arg: new class name
    char *zNewClassName = (char *) sqlite3_value_text(argv[1]);

    sqlite3 *db = sqlite3_context_db_handle(context);
    struct flexi_db_context *pCtx = sqlite3_user_data(context);

    sqlite3_int64 iOldID;
    int result;
    CHECK_CALL(db_get_name_id(pCtx, zOldClassName, &iOldID));
    CHECK_CALL(flexi_class_rename(pCtx, iOldID, zNewClassName));
    goto FINALLY;

    CATCH:
    zErr = (char *) sqlite3_errstr(result);
    sqlite3_result_error(context, zErr, -1);

    FINALLY:
    {};
}

void flexi_change_object_class(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{}

void flexi_prop_to_obj_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{}

void flexi_obj_to_props_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{}

void flexi_class_def_free(struct flexi_class_def *pClsDef)
{
    if (pClsDef != NULL)
    {
        if (pClsDef->pProps != NULL)
        {
            for (int idx = 0; idx < pClsDef->nCols; idx++)
            {
                flexi_prop_def_free(&pClsDef->pProps[idx]);
            }
        }

        //        sqlite3_free(pClsDef->pSortedProps);
        sqlite3_free(pClsDef->pProps);
        sqlite3_free((void *) pClsDef->zHash);

        HashTable_clear(&pClsDef->propMap);

        sqlite3_free(pClsDef);
    }
}

const static FlexiTypesToSqliteTypeMap g_FlexiTypesToSqliteTypes[] = {
        {"text",     "TEXT",    PROP_TYPE_TEXT},
        {"integer",  "INTEGER", PROP_TYPE_INTEGER},
        {"boolean",  "INTEGER", PROP_TYPE_BOOLEAN},
        {"enum",     "INTEGER", PROP_TYPE_ENUM},
        {"number",   "FLOAT",   PROP_TYPE_NUMBER},
        {"datetime", "FLOAT",   PROP_TYPE_DATETIME},
        {"uuid",     "BLOB",    PROP_TYPE_UUID},
        {"binary",   "BLOB",    PROP_TYPE_BINARY},
        {"name",     "TEXT",    PROP_TYPE_NAME},
        {"decimal",  "FLOAT",   PROP_TYPE_DECIMAL},
        {"json",     "JSON1",   PROP_TYPE_JSON},
        {"date",     "FLOAT",   PROP_TYPE_DATE},
        {"time",     "FLOAT",   PROP_TYPE_TIMESPAN},
        {NULL,       "TEXT",    PROP_TYPE_TEXT}
        /* TODO
         * NVARCHAR
         * NCHAR
         * MONEY
         * IMAGE
         * VARCHAR
         */
};

static const FlexiTypesToSqliteTypeMap *findSqliteTypeByFlexiType(const char *t)
{
    int ii = 0;
    for (; ii < sizeof(g_FlexiTypesToSqliteTypes) / sizeof(g_FlexiTypesToSqliteTypes[0]); ii++)
    {
        if (g_FlexiTypesToSqliteTypes[ii].zFlexi_t && strcmp(g_FlexiTypesToSqliteTypes[ii].zFlexi_t, t) == 0)
            return &g_FlexiTypesToSqliteTypes[ii];
    }

    return &g_FlexiTypesToSqliteTypes[sizeof(g_FlexiTypesToSqliteTypes) / sizeof(g_FlexiTypesToSqliteTypes[0]) - 1];
}

/*
 * Generates SQL to create Flexilite virtual table from class definition
 */
int flexi_class_def_generate_vtable_sql(struct flexi_class_def *pClassDef, char **zSQL)
{
    int result;

    char *sbClassDef = sqlite3_mprintf("create table [%s] (", pClassDef->iClassID);
    if (!sbClassDef)
    {
        result = SQLITE_NOMEM;
        goto CATCH;
    }

    // TODO
    int nPropIdx = 0;

    if (nPropIdx != 0)
    {
        void *pTmp = sbClassDef;
        sbClassDef = sqlite3_mprintf("%s,", pTmp);
        sqlite3_free(pTmp);
    }

    {
        // TODO
        var pPropType = NULL;
        void *pTmp = sbClassDef;
        sbClassDef = sqlite3_mprintf("%s[%s] %s", pTmp, pClassDef->pProps[nPropIdx].name.name, pPropType);
        sqlite3_free(pTmp);
    }

    {
        void *pTmp = sbClassDef;
        sbClassDef = sqlite3_mprintf("%s);", pTmp);
        sqlite3_free(pTmp);
    }

    // Fix strange issue with misplaced terminating zero
    CHECK_CALL(sqlite3_declare_vtab(pClassDef->pCtx->db, sbClassDef));

    goto FINALLY;

    CATCH:

    FINALLY:
    sqlite3_free(sbClassDef);

    return 0;
}

/*
 * Loads class definition from [.classes] and [flexi_prop] tables
 * into ppVTab (casted to flexi_class_def).
 * Used by Create and Connect methods
 */
int flexi_class_def_load(struct flexi_db_context *pCtx, sqlite3_int64 lClassID, struct flexi_class_def **pClassDef,
                         const char **pzErr)
{
    int result;

    *pClassDef = flexi_class_def_new(pCtx);
    if (!*pClassDef)
    {
        result = SQLITE_NOMEM;
        goto CATCH;
    }

    // Initialize variables
    sqlite3_stmt *pGetClassStmt = NULL;

    char *zPropDefJson = NULL;

    // TODO Use context statements
    // Init property metadata
    const char *zGetClassSQL = "select "
            "ClassID, " // 0
            "NameID, " // 1
            "SystemClass, " // 2
            "ctloMask, " // 3
            "Hash, " // 4
            "AsTable " // 5
            "from [.classes] "
            "where ClassID = :1;";
    CHECK_CALL(sqlite3_prepare_v2(pCtx->db, zGetClassSQL, -1, &pGetClassStmt, NULL));
    sqlite3_bind_int64(pGetClassStmt, 1, lClassID);
    result = sqlite3_step(pGetClassStmt);
    if (result == SQLITE_DONE)
        // No class found. Return error
    {
        result = SQLITE_NOTFOUND;
        if (pzErr)
            *pzErr = sqlite3_mprintf("Cannot find Flexilite class with ID [%ld]", lClassID);
        goto CATCH;
    }

    if (result != SQLITE_ROW)
        goto CATCH;

    (*pClassDef)->iClassID = sqlite3_column_int64(pGetClassStmt, 0);
    (*pClassDef)->name.id = sqlite3_column_int64(pGetClassStmt, 1);
    (*pClassDef)->bSystemClass = (short int) sqlite3_column_int(pGetClassStmt, 2);
    (*pClassDef)->xCtloMask = sqlite3_column_int(pGetClassStmt, 3);

    {
        int iHashLen = sqlite3_column_bytes(pGetClassStmt, 4);
        if (iHashLen > 0)
        {
            (*pClassDef)->zHash = sqlite3_malloc(iHashLen + 1);
            strcpy((*pClassDef)->zHash, (char *) sqlite3_column_text(pGetClassStmt, 4));
        }
    }

    // Load properties from flexi_prop
    if (!pCtx->pStmts[STMT_LOAD_CLS_PROP])
    {
        CHECK_CALL(sqlite3_prepare_v2(pCtx->db, "select"
                                              "PropertyID," // 0
                                              "Class, " // 1
                                              "NameID, " // 2
                                              "Property," // 3
                                              "ctlv," // 4
                                              "ctlvPlan," // 5
                                              "Definition" // 6
                                              " from [flexi_prop] where ClassID=:1", -1,
                                      &pCtx->pStmts[STMT_LOAD_CLS_PROP], NULL));

    }
    CHECK_CALL(sqlite3_reset(pCtx->pStmts[STMT_LOAD_CLS_PROP]));
    CHECK_CALL(sqlite3_bind_int64(pCtx->pStmts[STMT_LOAD_CLS_PROP], 1, lClassID));
    while (true)
    {
        CHECK_STMT(sqlite3_step(pCtx->pStmts[STMT_LOAD_CLS_PROP]));
        if (result == SQLITE_DONE)
            break;

        struct flexi_prop_def *pProp = flexi_prop_def_new(lClassID);
        if (!pProp)
        {
            result = SQLITE_NOMEM;
            goto CATCH;
        }

        sqlite3_free(zPropDefJson);
        zPropDefJson = (char *) sqlite3_column_text(pCtx->pStmts[STMT_LOAD_CLS_PROP], 6);
        char *zPropName = (char *) sqlite3_column_text(pCtx->pStmts[STMT_LOAD_CLS_PROP], 3);
        CHECK_CALL(flexi_prop_def_parse(pProp, zPropName, zPropDefJson));

        HashTable_set(&(*pClassDef)->propMap, zPropName, pProp);
    }

    (*pClassDef)->nCols = (*pClassDef)->propMap.count;

    // TODO Process specialProperties, mixins, fullTextProps, rangeProps

    result = SQLITE_OK;
    goto FINALLY;

    CATCH:
    if (*pClassDef)
    {
        flexi_class_def_free(*pClassDef);
        *pClassDef = NULL;
    }
    if (pzErr && !*pzErr)
        *pzErr = sqlite3_errstr(result);
    sqlite3_free(zPropDefJson);

    FINALLY:
    if (pGetClassStmt)
        sqlite3_finalize(pGetClassStmt);

    return result;
}

static void _disposeMixinRuleItem(struct flexi_mixin_rule *rr)
{
    sqlite3_free(rr->classRef.name);
    sqlite3_free(rr->regex);
    sqlite3_free(rr->zExactValue);
}

void flexi_class_mixin_init(struct flexi_class_mixin_def *p)
{
    memset(p, 0, sizeof(*p));
    Buffer_init(&p->rules, sizeof(struct flexi_mixin_rule), (void *) _disposeMixinRuleItem);
}

void flexi_class_mixin_def_free(struct flexi_class_mixin_def *p)
{
    if (p)
    {
        Buffer_done(&p->rules);
        sqlite3_free(p->classRef.name);
        sqlite3_free(p->dynSelectorProp.name);
    }
}
