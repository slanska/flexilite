//
// Created by slanska on 2017-02-08.
//

/*
 * flexi_class implementation of Flexilite class API
 */

#include "flexi_class.h"

/*
 * Create new class record in the database. Data field is not saved at this point yet
 */
static int _create_class_record(struct flexi_Context_t *pCtx, const char *zClassName, const char *zOriginalClassDef,
                                sqlite3_int64 *plClassID)
{
    int result;
    sqlite3_stmt *pStmt;
    CHECK_CALL(
            flexi_Context_stmtInit(pCtx, STMT_INS_CLS, "insert into [.classes] (NameID, OriginalData) values (:1, :2);",
                                   &pStmt));
    sqlite3_int64 lClassNameID;
    CHECK_CALL(flexi_Context_insertName(pCtx, zClassName, &lClassNameID));
    CHECK_SQLITE(pCtx->db, sqlite3_bind_int64(pStmt, 1, lClassNameID));
    CHECK_SQLITE(pCtx->db, sqlite3_bind_text(pStmt, 2, zOriginalClassDef, -1, NULL));
    CHECK_STMT_STEP(pStmt, pCtx->db);
    CHECK_CALL(flexi_Context_getClassIdByName(pCtx, zClassName, plClassID));

    goto EXIT;

    ONERROR:

    EXIT:
    return result;
}

/// @brief Parses specialProperties block of class definition ({specialProperties})
/// @param pClassDef Pointer to class definition object
/// @param zClassDefJson Class definition JSON string to be parsed
/// @return 0 (SQLITE_OK) is processing was successful
static int _parseSpecialProperties(struct flexi_ClassDef_t *pClassDef, const char *zClassDefJson)
{
    int result;

    sqlite3_stmt *pStmt = NULL;

    const char *zSpecProps[] = {
            "uid", "name", "description", "code", "nonUniqueId", "createTime",
            "updateTime", "autoUuid", "autoShortId"
    };
    char *zSql = NULL;
    zSql = sqlite3_mprintf("select ");

    char sep[] = " ";
    for (int ii = 0; ii < ARRAY_LEN(zSpecProps); ii++)
    {
        char *zTemp = zSql;
        const char *zp = zSpecProps[ii];
        zSql = sqlite3_mprintf("%s%s\n json_extract(:1, '$.specialProperties.%s.$id') as %s_id," // 3 * ii + 0
                                       "json_extract(:1, '$.specialProperties.%s.$name') as %s_name," // 3 * ii + 1
                                       "json_extract(:1, '$.specialProperties.%s') as %s", // 3 * ii + 2
                               zTemp, sep, zp, zp, zp, zp, zp, zp);
        sep[0] = ',';
        sqlite3_free(zTemp);
    }

    CHECK_STMT_PREPARE(pClassDef->pCtx->db, zSql, &pStmt);
    CHECK_SQLITE(pClassDef->pCtx->db, sqlite3_bind_text(pStmt, 1, zClassDefJson, -1, NULL));
    CHECK_STMT_STEP(pStmt, pClassDef->pCtx->db);
    if (result == SQLITE_ROW)
    {
        for (int ii = 0; ii < ARRAY_LEN(pClassDef->aSpecProps); ii++)
        {
            flexi_MetadataRef_t *specProp = &pClassDef->aSpecProps[ii];
            CHECK_CALL(getColumnAsText(&specProp->name, pStmt, ii * 3 + 1));
            specProp->bOwnName = specProp->name != NULL;
            specProp->id = sqlite3_column_int64(pStmt, ii * 3);
            if (!specProp->bOwnName && specProp->id == 0)
            {
                CHECK_CALL(getColumnAsText(&specProp->name, pStmt, ii * 3 + 2));
                specProp->bOwnName = specProp->name != NULL;
            }
        }
    }

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    sqlite3_finalize(pStmt);
    sqlite3_free(zSql);

    return result;
}

static int _parseRangeProperties(struct flexi_ClassDef_t *pClassDef, const char *zClassDefJson)
{
    int result;
    const char *zCols = "A0A1B0B1C0C1D0D1E0E1";
    char *zSql = NULL;
    sqlite3_stmt *pStmt = NULL;
    const char *zp = zCols;
    zSql = sqlite3_mprintf("select ");
    char sep = ' ';
    for (int ii = 0; ii < strlen(zCols); ii += 2, zp += 2)
    {
        char *zTemp = zSql;
        zSql = sqlite3_mprintf("%s%c\njson_extract(:1, '$.rangeIndexing.%.2s.$id') as %.2s_id, "
                                       "json_extract(:1, '$.rangeIndexing.%.2s.$name') as %.2s_name",
                               zTemp, sep, zp, zp, zp, zp);
        sqlite3_free(zTemp);
        sep = ',';
    }

    CHECK_STMT_PREPARE(pClassDef->pCtx->db, zSql, &pStmt);
    CHECK_SQLITE(pClassDef->pCtx->db, sqlite3_bind_text(pStmt, 1, zClassDefJson, -1, NULL));
    CHECK_STMT_STEP(pStmt, pClassDef->pCtx->db);
    if (result == SQLITE_ROW)
    {
        for (int ii = 0; ii < ARRAY_LEN(pClassDef->aRangeProps); ii += 2)
        {
            pClassDef->aRangeProps[ii].bOwnName = true;
            pClassDef->aRangeProps[ii].id = sqlite3_column_int64(pStmt, ii);
            CHECK_CALL(getColumnAsText(&pClassDef->aRangeProps[ii].name, pStmt, ii));
        }

    }

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:
    EXIT:
    sqlite3_free(zSql);
    sqlite3_finalize(pStmt);
    return result;
}

static int _parseFullTextProperties(struct flexi_ClassDef_t *pClassDef, const char *zClassDefJson)
{
    int result;
    char *zSql = NULL;
    zSql = sqlite3_mprintf("select ");
    char c = ' ';
    for (int ii = 0; ii < ARRAY_LEN(pClassDef->aFtsProps); ii++)
    {
        char *zTemp = zSql;
        int idx = ii + 1;
        zSql = sqlite3_mprintf("%s%c\n"
                                       "json_extract(:1, '$.fullTextIndexing.X%d.$id') as X%d_id,"
                                       "json_extract(:1, '$.fullTextIndexing.X%d.$name') as X%d_name",
                               zTemp, c, idx, idx, idx, idx);

        sqlite3_free(zTemp);
        c = ',';
    }

    sqlite3_stmt *pStmt = NULL;
    CHECK_STMT_PREPARE(pClassDef->pCtx->db, zSql, &pStmt);
    CHECK_SQLITE(pClassDef->pCtx->db, sqlite3_bind_text(pStmt, 1, zClassDefJson, -1, NULL));
    CHECK_STMT_STEP(pStmt, pClassDef->pCtx->db);
    if (result == SQLITE_ROW)
    {
        for (int ii = 0; ii < ARRAY_LEN(pClassDef->aFtsProps); ii++)
        {
            pClassDef->aFtsProps[ii].bOwnName = true;
            pClassDef->aFtsProps[ii].id = sqlite3_column_int64(pStmt, ii * 2);
            CHECK_CALL(getColumnAsText(&pClassDef->aFtsProps[ii].name, pStmt, ii * 2 + 1));
        }
    }

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    sqlite3_finalize(pStmt);
    sqlite3_free(zSql);

    return result;
}

static int _parseMixins(struct flexi_ClassDef_t *pClassDef, const char *zClassDefJson)
{
    int result;

    sqlite3_stmt *pStmt = NULL;
    sqlite3_stmt *pRulesStmt = NULL;
    char *zRulesJson = NULL;

    char *zSql = "select json_extract(value, '$.classRef.$id')," // 0
            "json_extract(value, '$.classRef.$name'), " // 1
            "json_extract(value, '$.dynamic.selectorProp.$id'), " // 2
            "json_extract(value, '$.dynamic.selectorProp.$name'), " // 3
            "json_extract(value, '$.dynamic.rules') " // 4
            "from json_each(:1, '$.mixins')";
    CHECK_STMT_PREPARE(pClassDef->pCtx->db, zSql, &pStmt);
    CHECK_CALL(sqlite3_bind_text(pStmt, 1, zClassDefJson, -1, NULL));
    while (true)
    {
        CHECK_STMT_STEP(pStmt, pClassDef->pCtx->db);
        if (result == SQLITE_DONE)
            break;

        if (pClassDef->aMixins == NULL)
            pClassDef->aMixins = Array_new(sizeof(struct flexi_ClassRefDef), (void *) flexi_ClassRefDef_dispose);

        struct flexi_ClassRefDef *mixin = Array_append(pClassDef->aMixins);
        if (!mixin)
        {
            result = SQLITE_NOMEM;
            goto ONERROR;
        }

        flexi_ClassRefDef_init(mixin);

        CHECK_CALL(getColumnAsText(&mixin->classRef.name, pStmt, 1));
        mixin->classRef.bOwnName = true;
        mixin->classRef.id = sqlite3_column_int64(pStmt, 0);

        mixin->dynSelectorProp.id = sqlite3_column_int64(pStmt, 2);
        CHECK_CALL(getColumnAsText(&mixin->dynSelectorProp.name, pStmt, 3));
        mixin->dynSelectorProp.bOwnName = true;

        CHECK_CALL(getColumnAsText(&zRulesJson, pStmt, 4));
        char *zRulesSql = "select json_extract(value, '$.regex') as regex," // 0
                "json_extract(value, '$.classRef.$id') as classId," // 1
                "json_extract(value, '$.classRef.$name') as className" // 2
                "from json_each(:1);";
        CHECK_STMT_PREPARE(pClassDef->pCtx->db, zRulesSql, &pRulesStmt);
        CHECK_CALL(sqlite3_bind_text(pRulesStmt, 1, zRulesJson, -1, NULL));
        while (true)
        {
            CHECK_STMT_STEP(pRulesStmt, pClassDef->pCtx->db);
            if (result != SQLITE_ROW)
                break;

            struct flexi_ClassRefRule *rule = Array_append(&mixin->rules);
            if (!rule)
            {
                result = SQLITE_NOMEM;
                goto ONERROR;
            }

            CHECK_CALL(getColumnAsText(&rule->regex, pRulesStmt, 0));
            rule->classRef.id = sqlite3_column_int64(pRulesStmt, 1);
            CHECK_CALL(getColumnAsText(&rule->classRef.name, pRulesStmt, 2));
            rule->classRef.bOwnName = true;
        }
    }

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:
    if (pClassDef->aMixins)
    {
        Array_free(pClassDef->aMixins);
        pClassDef->aMixins = NULL;
    }

    EXIT:
    sqlite3_free(zRulesJson);
    sqlite3_finalize(pStmt);
    sqlite3_finalize(pRulesStmt);
    return result;
}

/*
 * Processes properties in prepared pStmt statement.
 * Columns returned by pStmt are defined by iPropNameCol and iPropDefCol (required).
 * Also, optionally iNameCol, ctlvCol and ictlvPlanCol can be passed
 */
static int _parseProperties(struct flexi_ClassDef_t *pClassDef, sqlite3_stmt *pStmt, int iPropNameCol,
                            int iPropDefCol, int iNameCol, int ictlvCol, int ictlvPlanCol)
{
    int result;

    char *zPropDefJson = NULL;

    while ((result = sqlite3_step(pStmt)) == SQLITE_ROW)
    {
        struct flexi_PropDef_t *pProp = flexi_PropDef_new(pClassDef->lClassID);
        if (!pProp)
        {
            result = SQLITE_NOMEM;
            goto ONERROR;
        }

        pProp->pCtx = pClassDef->pCtx;

        sqlite3_free(zPropDefJson);
        zPropDefJson = NULL;

        // Get property JSON
        CHECK_CALL(getColumnAsText(&zPropDefJson, pStmt, iPropDefCol));

        // Get property name
        CHECK_CALL(getColumnAsText(&pProp->name.name, pStmt, iPropNameCol));
        CHECK_CALL(flexi_prop_def_parse(pProp, pProp->name.name, zPropDefJson));

        if (iNameCol >= 0)
        {
            pProp->name.id = sqlite3_column_int64(pStmt, iNameCol);
        }

        if (ictlvCol >= 0)
        {
            pProp->xCtlv = sqlite3_column_int(pStmt, ictlvCol);
        }

        if (ictlvPlanCol >= 0)
        {
            pProp->xCtlvPlan = sqlite3_column_int(pStmt, ictlvPlanCol);
        }

        HashTable_set(&pClassDef->propsByName, (DictionaryKey_t) {.pKey=pProp->name.name}, pProp);
        HashTable_set(&pClassDef->propsByID, (DictionaryKey_t) {.iKey = pProp->iPropID}, pProp);
    }

    if (result != SQLITE_DONE)
        goto ONERROR;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    sqlite3_free(zPropDefJson);

    return result;
}

static int _parseClassDefAux(struct flexi_ClassDef_t *pClassDef, const char *zClassDefJson)
{
    int result;
    sqlite3_stmt *pAuxAttrs = NULL;

    CHECK_CALL(_parseFullTextProperties(pClassDef, zClassDefJson));
    CHECK_CALL(_parseMixins(pClassDef, zClassDefJson));
    CHECK_CALL(_parseRangeProperties(pClassDef, zClassDefJson));
    CHECK_CALL(_parseSpecialProperties(pClassDef, zClassDefJson));

    // Get other properties
    CHECK_STMT_PREPARE(pClassDef->pCtx->db, "select "
            "json_extract(:1, '$.allowAnyProps') as allowAnyProps", // 0
                       &pAuxAttrs);
    CHECK_CALL(sqlite3_bind_text(pAuxAttrs, 1, zClassDefJson, -1, NULL));
    result = sqlite3_step(pAuxAttrs);
    if (result == SQLITE_ROW)
    {
        pClassDef->bAllowAnyProps = sqlite3_column_int(pAuxAttrs, 0) != 0;
    }

    result = SQLITE_OK;

    goto EXIT;
    ONERROR:
    EXIT:
    sqlite3_finalize(pAuxAttrs);
    return result;
}

/*
 * Dummy no-op function. To be used as replacement for default free item
 * callback in hash table
 */
static void _dummy_ptr(void *ptr)
{
    UNUSED_PARAM(ptr);
}

/*
 * Allocates and initializes new instance of class definition
 */
struct flexi_ClassDef_t *flexi_class_def_new(struct flexi_Context_t *pCtx)
{
    struct flexi_ClassDef_t *result = sqlite3_malloc(sizeof(struct flexi_ClassDef_t));
    if (!result)
        return result;
    memset(result, 0, sizeof(*result));

    result->pCtx = pCtx;
    HashTable_init(&result->propsByName, DICT_STRING_NO_FREE, (void *) flexi_PropDef_free);
    HashTable_init(&result->propsByID, DICT_INT, (void *) _dummy_ptr);
    return result;
}

/// @brief Creates a new Flexilite class, based on name and JSON definition.
/// Class must not exist
/// @param zClassName
/// @param zOriginalClassDef
/// @param bCreateVTable
/// @param pzError
/// @return
int flexi_ClassDef_create(struct flexi_Context_t *pCtx, const char *zClassName, const char *zOriginalClassDef,
                          bool bCreateVTable)
{
    int result;

    // Disposable resources
    sqlite3_stmt *pExtractProps = NULL;
    sqlite3_stmt *pInsClsStmt = NULL;
    sqlite3_stmt *pInsPropStmt = NULL;
    sqlite3_stmt *pUpdClsStmt = NULL;
    char *zPropDefJSON = NULL;

    struct flexi_PropDef_t dProp;
    memset(&dProp, 0, sizeof(dProp));

    // Check if class does not exist yet
    sqlite3_int64 lClassID;
    CHECK_CALL(flexi_Context_getClassIdByName(pCtx, zClassName, &lClassID));
    if (lClassID > 0)
    {
        result = SQLITE_ERROR;
        flexi_Context_setError(pCtx, result, sqlite3_mprintf("Class [%s] already exists", zClassName));
        goto ONERROR;
    }

    if (!db_validate_name(zClassName))
    {
        result = SQLITE_ERROR;
        flexi_Context_setError(pCtx, result, sqlite3_mprintf("Invalid class name [%s]", zClassName));
        goto ONERROR;
    }

    // Create (non-complete) record in .classes table
    CHECK_CALL(_create_class_record(pCtx, zClassName, zOriginalClassDef, &lClassID));

    CHECK_CALL(
            _flexi_ClassDef_applyNewDef(pCtx, lClassID, zOriginalClassDef, bCreateVTable, INVALID_DATA_ABORT));

    result = SQLITE_OK;

    goto EXIT;

    ONERROR:
    // Release resources because of errors (catch)

    EXIT:

    sqlite3_free((void *) zPropDefJSON);
    sqlite3_free(dProp.name.name);

    sqlite3_finalize(pExtractProps);
    sqlite3_finalize(pInsClsStmt);
    sqlite3_finalize(pUpdClsStmt);
    sqlite3_finalize(pInsPropStmt);

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
int flexi_class_create_func(
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
    bool bCreateVTable = false;
    if (argc == 3)
        bCreateVTable = sqlite3_value_int(argv[2]) != 0;

    const char *zError = NULL;

    sqlite3 *db = sqlite3_context_db_handle(context);

    int result;
    char *zSQL = NULL;
    if (bCreateVTable)
    {
        zSQL = sqlite3_mprintf("create virtual table [%s] using flexi ('%s')", zClassName, zClassDef);
        CHECK_SQLITE(db, sqlite3_exec(db, zSQL, NULL, NULL, (char **) &zError));
    }
    else
    {
        void *pCtx = sqlite3_user_data(context);
        CHECK_CALL(flexi_ClassDef_create(pCtx, zClassName, zClassDef, bCreateVTable));
    }

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:
    if (zError)
    {
        sqlite3_result_error(context, zError, result);
        sqlite3_free((void *) zError);
    }

    EXIT:
    sqlite3_free(zSQL);
    return result;
}

///
/// \param context
/// \param argc
/// \param argv
int flexi_class_alter_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    assert(argc >= 2 && argc <= 4);

    int result = SQLITE_OK;
    const char *zError = NULL;

    // 1st arg: class name
    char *zClassName = (char *) sqlite3_value_text(argv[0]);

    // 2nd arg: new class definition
    char *zNewClassDef = (char *) sqlite3_value_text(argv[1]);

    // 3rd optional argument - create virtual table for class
    bool bCreateVTable = false;
    if (argc == 3)
        bCreateVTable = (bool) sqlite3_value_int(argv[2]);

    /*
     * 4th optional parameter - validation mode: ABORT (0) - in case of any data that cannot be converted
     * to a new property, entire alter operation will be aborted,
     * IGNORE (1) - all data validation errors will be ignored but corresponding properties
     * and class itself will get ValidationNeeded flag set.
     * This flag can be attempted to clear by flexi('validate data')
     */
    const char *zValidateMode = NULL;
    enum ALTER_CLASS_DATA_VALIDATION_MODE eValidationMode = INVALID_DATA_ABORT;
    if (argc == 4)
    {
        const static struct
        {
            const char *opName;
            enum ALTER_CLASS_DATA_VALIDATION_MODE opCode;
        }
                g_DataValidationModes[] = {
                {"ABORT",  INVALID_DATA_ABORT},
                {"0",      INVALID_DATA_ABORT},
                {"IGNORE", INVALID_DATA_IGNORE},
                {"1",      INVALID_DATA_IGNORE}
        };
        zValidateMode = (char *) sqlite3_value_text(argv[3]);
        if (zValidateMode)
        {
            eValidationMode = INVALID_DATA_ERROR;
            for (int iValMode = 0; iValMode < ARRAY_LEN(g_DataValidationModes); iValMode++)
            {
                if (sqlite3_stricmp(zValidateMode, g_DataValidationModes[iValMode].opName) == 0)
                {
                    eValidationMode = g_DataValidationModes[iValMode].opCode;
                    break;
                }
            }

            if (eValidationMode == INVALID_DATA_ERROR)
            {
                zError = sqlite3_mprintf(
                        "Invalid data validation mode - \"%s\". Supported values are: ABORT (default) or IGNORE",
                        zValidateMode);
                goto ONERROR;
            }
        }
    }
    struct flexi_Context_t *pCtx = sqlite3_user_data(context);
    CHECK_CALL(flexi_class_alter(pCtx, zClassName, zNewClassDef, eValidationMode, bCreateVTable));

    goto EXIT;

    ONERROR:
    if (zError)
        sqlite3_result_error(context, zError, -1);

    EXIT:

    sqlite3_free(zClassName);
    sqlite3_free((void *) zValidateMode);
    sqlite3_free(zNewClassDef);

    return result;
}

int flexi_class_drop(struct flexi_Context_t *pCtx, sqlite3_int64 lClassID, int softDelete)
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
int flexi_class_drop_func(
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
    struct flexi_Context_t *pCtx = sqlite3_user_data(context);
    CHECK_CALL(flexi_Context_getClassIdByName(pCtx, zClassName, &lClassID));

    CHECK_CALL(flexi_class_drop(pCtx, lClassID, softDel));
    goto EXIT;

    ONERROR:
    if (!zError)
        sqlite3_result_error(context, zError, -1);
    else
        if (result != SQLITE_OK)
            sqlite3_result_error(context, sqlite3_errstr(result), -1);

    EXIT:
    return result;
}

/// @brief
/// @param pCtx
/// @param iOldClassID
/// @param zNewName
/// @return
int flexi_class_rename(struct flexi_Context_t *pCtx, sqlite3_int64 iOldClassID, const char *zNewName)
{
    assert(pCtx && pCtx->db);

    int result;

    sqlite3_int64 lNewNameID;
    sqlite3_stmt *pStmt;
    CHECK_CALL(flexi_Context_insertName(pCtx, zNewName, &lNewNameID));

    // TODO Move to prepared statements
    CHECK_CALL(flexi_Context_stmtInit(pCtx, STMT_CLS_RENAME, "update [.classes] set NameID = :1 "
            "where ClassID = :2;", &pStmt));
    sqlite3_bind_int64(pStmt, 1, lNewNameID);
    sqlite3_bind_int64(pStmt, 2, iOldClassID);
    CHECK_STMT_STEP(pStmt, pCtx->db);
    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:

    return result;
}

/*
 * Handler for flexi('rename class'...)
 */
int flexi_class_rename_func(
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
    struct flexi_Context_t *pCtx = sqlite3_user_data(context);

    sqlite3_int64 iOldID;
    int result;
    CHECK_CALL(flexi_Context_getNameId(pCtx, zOldClassName, &iOldID));
    CHECK_CALL(flexi_class_rename(pCtx, iOldID, zNewClassName));
    goto EXIT;

    ONERROR:
    zErr = (char *) sqlite3_errstr(result);
    sqlite3_result_error(context, zErr, -1);

    EXIT:
    return result;
}

/*
 * Handler for flexi('change object class'...)
 */

int flexi_change_object_class_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    int result;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;
}

/*
 * Handler for flexi('properties to object'...)
 */

int flexi_prop_to_obj_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    int result;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;

}

/*
 * Handler for flexi('object to properties'...)
 */
int flexi_obj_to_props_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    int result;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;

}

void flexi_ClassDef_free(struct flexi_ClassDef_t *self)
{
    if (self != NULL)
    {
        if (self->nRefCount > 0)
            self->nRefCount--;

        if (self->nRefCount == 0)
        {
            sqlite3_free((void *) self->zHash);

            HashTable_clear(&self->propsByName);
            HashTable_clear(&self->propsByID);

            Array_free(self->aMixins);

            for (int ii = 0; ii < ARRAY_LEN(self->aSpecProps); ii++)
            {
                flexi_MetadataRef_free(&self->aSpecProps[ii]);
            }

            for (int ii = 0; ii < ARRAY_LEN(self->aFtsProps); ii++)
            {
                flexi_MetadataRef_free(&self->aFtsProps[ii]);
            }

            for (int ii = 0; ii < ARRAY_LEN(self->aRangeProps); ii++)
            {
                flexi_MetadataRef_free(&self->aRangeProps[ii]);
            }

            sqlite3_free(self);
        }
    }
}

/*
 * Generates SQL to create Flexilite virtual table from class definition
 */
int flexi_ClassDef_generateVtableSql(struct flexi_ClassDef_t *pClassDef, char **zSQL)
{
    int result;

    char *sbClassDef = sqlite3_mprintf("create table [%s] (", pClassDef->lClassID);
    if (!sbClassDef)
    {
        result = SQLITE_NOMEM;
        goto ONERROR;
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
    CHECK_SQLITE(pClassDef->pCtx->db, sqlite3_declare_vtab(pClassDef->pCtx->db, sbClassDef));

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    sqlite3_free(sbClassDef);

    return result;
}

/*
 * Sets property name ID
 */
static void
_getPropNameID(const char *zKey, const sqlite3_int64 index, struct flexi_PropDef_t *prop,
               const var collection, flexi_ClassDef_t *pClassDef, bool *bStop)
{
    UNUSED_PARAM(zKey);
    UNUSED_PARAM(index);
    UNUSED_PARAM(collection);

    int result = flexi_Context_insertName(pClassDef->pCtx, prop->name.name, &prop->name.id);
    if (result != SQLITE_OK)
    {
        // TODO use alter context and set error
        *bStop = true;
    }
}

/*
 * Parses class definition JSON into classDef structure (which is supposed to be already allocated and zeroed)
 */
int flexi_ClassDef_parse(struct flexi_ClassDef_t *pClassDef, const char *zClassDefJson)
{
    int result;

    sqlite3_stmt *pStmt = NULL;

    // Load properties
    char *zPropSql = "select key as Name, value as Definition from json_each(:1, '$.properties');";
    CHECK_STMT_PREPARE(pClassDef->pCtx->db, zPropSql, &pStmt);
    CHECK_SQLITE(pClassDef->pCtx->db, sqlite3_bind_text(pStmt, 1, zClassDefJson, -1, NULL));
    CHECK_SQLITE(pClassDef->pCtx->db, _parseProperties(pClassDef, pStmt, 0, 1, -1, -1, -1));

    // Get property name IDs
    HashTable_each(&pClassDef->propsByName, (void *) _getPropNameID, pClassDef);

    // Process other elements of class definition
    CHECK_CALL(_parseClassDefAux(pClassDef, zClassDefJson));
    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    sqlite3_finalize(pStmt);
    return result;
}

/*
 * Loads class definition (as defined in [.classes] and [flexi_prop] tables)
 * First checks if class def has been already loaded, and if so, simply returns it
 * Otherwise, will load class definition from database and add it to the context class def collection
 * If class is not found, will return the error
 */
int flexi_ClassDef_load(struct flexi_Context_t *pCtx, sqlite3_int64 lClassID, struct flexi_ClassDef_t **pClassDef)
{
    int result;
    char *zClassDefJson = NULL;

    *pClassDef = HashTable_get(&pCtx->classDefsById, (DictionaryKey_t) {.iKey = lClassID});
    if (*pClassDef != NULL)
        return SQLITE_OK;

    *pClassDef = flexi_class_def_new(pCtx);
    if (!*pClassDef)
    {
        result = SQLITE_NOMEM;
        goto ONERROR;
    }

    // Initialize variables
    sqlite3_stmt *pGetClassStmt = NULL;

    // TODO Use context statements
    // Init property metadata
    const char *zGetClassSQL = "select "
            "ClassID, " // 0
            "NameID, " // 1
            "SystemClass, " // 2
            "ctloMask, " // 3
            "VirtualTable, " // 4
            "Data as Definition, " // 5
            "(select [Value] from [.names_props] np where np.ID = [.classes].NameID limit 1) as Name " // 6
            "from [.classes] "
            "where ClassID = :1;";
    CHECK_STMT_PREPARE(pCtx->db, zGetClassSQL, &pGetClassStmt);
    sqlite3_bind_int64(pGetClassStmt, 1, lClassID);
    result = sqlite3_step(pGetClassStmt);
    if (result == SQLITE_DONE)
        // No class found. Return error
    {
        result = SQLITE_NOTFOUND;
        flexi_Context_setError(pCtx, result, sqlite3_mprintf("Cannot find Flexilite class with ID [%ld]", lClassID));
        goto ONERROR;
    }

    if (result != SQLITE_ROW)
        goto ONERROR;

    (*pClassDef)->lClassID = sqlite3_column_int64(pGetClassStmt, 0);
    (*pClassDef)->name.id = sqlite3_column_int64(pGetClassStmt, 1);
    getColumnAsText(&(*pClassDef)->name.name, pGetClassStmt, 6);
    (*pClassDef)->name.bOwnName = true;

    (*pClassDef)->bSystemClass = (bool) sqlite3_column_int(pGetClassStmt, 2);
    (*pClassDef)->xCtloMask = sqlite3_column_int(pGetClassStmt, 3);

    // TODO Temp
    char *zClassDef = NULL;
    getColumnAsText(&zClassDef, pGetClassStmt, 5);

    // Load properties from flexi_prop
    CHECK_CALL(flexi_Context_stmtInit(pCtx, STMT_LOAD_CLS_PROP, "select "
            "PropertyID," // 0
            "Class, " // 1
            "NameID, " // 2
            "Property," // 3
            "ctlv," // 4
            "ctlvPlan," // 5
            "Definition" // 6
            " from [flexi_prop] where ClassID=:1", NULL));
    CHECK_SQLITE(pCtx->db, sqlite3_bind_int64(pCtx->pStmts[STMT_LOAD_CLS_PROP], 1, lClassID));
    CHECK_CALL(_parseProperties(*pClassDef, pCtx->pStmts[STMT_LOAD_CLS_PROP], 3, 6, 2, 4, 5));

    CHECK_CALL(getColumnAsText(&zClassDefJson, pGetClassStmt, 5));
    CHECK_CALL(_parseClassDefAux(*pClassDef, zClassDefJson));

    CHECK_CALL(flexi_Context_addClassDef(pCtx, *pClassDef));

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:
    if (*pClassDef)
    {
        flexi_ClassDef_free(*pClassDef);
        *pClassDef = NULL;
    }
    flexi_Context_setError(pCtx, result, NULL);

    EXIT:
    sqlite3_finalize(pGetClassStmt);
    sqlite3_free(zClassDefJson);

    sqlite3_free(zClassDef);

    return result;
}

int flexi_schema_func(sqlite3_context *context,
                      int argc,
                      sqlite3_value **argv)
{
    int result;

    sqlite3_stmt *pStmt = NULL;
    const char *zErr = NULL;
    char *zClassName = NULL;
    char *zClassDef = NULL;

    sqlite3 *db = sqlite3_context_db_handle(context);

    if (argc == 0)
    {
        // TODO
        // return schema definition
    }

    if (argc == 1 || argc == 2)
    {
        bool bCreateVTable = false;
        if (argc == 2)
            bCreateVTable = sqlite3_value_int(argv[1]) != 0;
        void *pCtx = sqlite3_user_data(context);
        CHECK_STMT_PREPARE(db, "select value, key from json_each(:1)", &pStmt);
        CHECK_SQLITE(db, sqlite3_bind_value(pStmt, 1, argv[0]));
        //        CHECK_SQLITE(db, sqlite3_bind_value(pStmt, 1, sqlite3_value_dup(argv[0])));

        while ((result = sqlite3_step(pStmt)) == SQLITE_ROW)
        {
            sqlite3_free(zClassDef);
            zClassDef = NULL;
            sqlite3_free(zClassName);
            zClassName = NULL;

            CHECK_CALL(getColumnAsText(&zClassDef, pStmt, 0));
            CHECK_CALL(getColumnAsText(&zClassName, pStmt, 1));

            CHECK_CALL(flexi_ClassDef_create(pCtx, zClassName, zClassDef, bCreateVTable));
        }

        if (result != SQLITE_DONE)
            goto ONERROR;
    }

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:
    if (zErr == NULL)
    {
        zErr = sqlite3_errmsg(db);
        if (zErr == NULL)
            zErr = (char *) sqlite3_errstr(result);
    }
    sqlite3_result_error(context, zErr, -1);

    EXIT:
    sqlite3_finalize(pStmt);
    sqlite3_free(zClassDef);
    sqlite3_free(zClassName);
    return result;
}

/*
 * Finds property definition by its ID
 */
bool flexi_ClassDef_getPropDefById(struct flexi_ClassDef_t *pClassDef,
                                   sqlite3_int64 lPropID, struct flexi_PropDef_t **propDef)
{
    *propDef = HashTable_get(&pClassDef->propsByID, (DictionaryKey_t) {.iKey = lPropID});
    return *propDef != NULL;
}

/*
 * Finds property definition by its name
 */
bool flexi_ClassDef_getPropDefByName(struct flexi_ClassDef_t *pClassDef,
                                     const char *zPropName, struct flexi_PropDef_t **propDef)
{
    *propDef = HashTable_get(&pClassDef->propsByName, (DictionaryKey_t) {.pKey = zPropName});
    return *propDef != NULL;
}

int flexi_ClassDef_loadByName(struct flexi_Context_t *pCtx, const char *zClassName, struct flexi_ClassDef_t **pClassDef)
{
    int result;
    sqlite3_int64 lClassID;
    CHECK_CALL(flexi_Context_getClassIdByName(pCtx, zClassName, &lClassID));
    if (lClassID < 0)
    {
        result = SQLITE_NOTFOUND;
        flexi_Context_setError(pCtx, result, sqlite3_mprintf("Class [%s] not found", zClassName));
        goto ONERROR;
    }
    CHECK_CALL(flexi_ClassDef_load(pCtx, lClassID, pClassDef));
    goto EXIT;

    ONERROR:

    EXIT:
    return result;
}
