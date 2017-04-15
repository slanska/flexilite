//
// Created by slanska on 2017-02-08.
//

/*
 * flexi_class implementation of Flexilite class API
 */

#include "flexi_class.h"
#include "../util/StringBuilder.h"
#include <inttypes.h>

struct _BuildInternalClassDefJSON_Ctx
{
    struct flexi_ClassDef_t *pClassDef;
    StringBuilder_t sb;
};

/*
 * Appends class data reference definition to the given JSON string builder sb
 */
static void
_buildMetadataRef(StringBuilder_t *sb, const char *zName, flexi_MetadataRef_t *ref, bool *appendComma)
{
    char zID[30];

    if (ref->id != 0 || ref->name != NULL)
    {
        if (appendComma != NULL && *appendComma)
        {
            StringBuilder_appendRaw(sb, ",", 1);
        }
        StringBuilder_appendJsonElem(sb, zName, -1);
        StringBuilder_appendRaw(sb, ":{", 2);

        StringBuilder_appendJsonElem(sb, "$id", -1);
        StringBuilder_appendRaw(sb, ":", 1);
        sprintf(zID, "%" PRId64, ref->id);
        StringBuilder_appendJsonElem(sb, zID, -1);

        // If ID is 0, it means that name is not yet resolved. Store name too for future processing
        if (ref->id == 0)
        {
            StringBuilder_appendRaw(sb, ",", 1);
            StringBuilder_appendJsonElem(sb, "$name", -1);
            StringBuilder_appendRaw(sb, ":", 1);
            StringBuilder_appendJsonElem(sb, ref->name, -1);
        }

        StringBuilder_appendRaw(sb, "}", 1);
    }
}

static void _appendClassRefDynRule(const char *zKey, const sqlite3_int64 index,
                                   struct flexi_class_ref_rule *pData,
                                   const var collection, StringBuilder_t *sb, bool *bStop)
{
    UNUSED_PARAM(zKey);
    UNUSED_PARAM(collection);
    UNUSED_PARAM(bStop);

    if (index > 0)
        StringBuilder_appendRaw(sb, ",", 1);
    StringBuilder_appendRaw(sb, "{", 1);
    StringBuilder_appendJsonElem(sb, "regex", -1);
    StringBuilder_appendJsonElem(sb, pData->regex, -1);
    StringBuilder_appendRaw(sb, ",", 1);
    _buildMetadataRef(sb, "classRef", &pData->classRef, NULL);
    StringBuilder_appendRaw(sb, "}", 1);
}

/*
 * Internal function to serialize class ref def data to JSON
 *  * declare interface TMixinClassDef {
    classRef?: IMetadataRef | IMetadataRef[],
    dynamic?: {
        selectorProp: IMetadataRef;
        rules: {
            regex: string | RegExp,
            classRef: IMetadataRef
        }[];
    }
}
 */
static void
_internalAppendClassDefRef(StringBuilder_t *sb, Flexi_ClassRefDef_t *classRefDef)
{
    bool appendComma = true;
    _buildMetadataRef(sb, "classRef", &classRefDef->classRef, NULL);

    if (classRefDef->dynSelectorProp.id != 0 || classRefDef->dynSelectorProp.name != NULL)
    {
        StringBuilder_appendRaw(sb, ",", 1);
        StringBuilder_appendJsonElem(sb, "dynamic", -1);
        StringBuilder_appendRaw(sb, ":{", 2);
        _buildMetadataRef(sb, "selectorProp", &classRefDef->dynSelectorProp, NULL);

        StringBuilder_appendRaw(sb, ",{", 2);
        StringBuilder_appendJsonElem(sb, "rules", -1);
        Array_each(&classRefDef->rules, (void *) _appendClassRefDynRule, sb);

        StringBuilder_appendRaw(sb, "}}", 2);
    }
}

/*
 * Appends class ref def (mixin class ref)

 */
static void
_buildClassDefRef(StringBuilder_t *sb, const char *zPropName, Flexi_ClassRefDef_t *classRefDef,
                  bool *appendComma)
{
    if (appendComma != NULL && *appendComma)
    {
        StringBuilder_appendRaw(sb, ",", 1);
    }

    StringBuilder_appendRaw(sb, "{", 1);
    _internalAppendClassDefRef(sb, classRefDef);
    StringBuilder_appendRaw(sb, "}", 1);
}

/*
 *
 */
static void
_buildPropDefJSON(const char *zKey, const sqlite3_int64 index, void *pData,
                  const var collection, struct _BuildInternalClassDefJSON_Ctx *ctx, bool *bStop)
{
    //    HashTable_get()

    /*
     * rules
     *
     * index
     *
     * noTrackChanges
     *
     * refDef
     *
     * enumDef
     *
     * defaultValue
     */

    // rules - as is

    // index - as is

    // refDef - use $id

    // enumDef - ???

    // defaultValue - as is
}

/*
 * Appends array of metadata references to string build sb as zName object property.
 * len defines number of items.
 * aMeta - array of metadata refs
 * zProps - names for items (number should be equal to len)
 */
static void
_buildMetaDataRefArray(StringBuilder_t *sb, const char *zPropName, flexi_MetadataRef_t *aMeta, const char *zProps[],
                       int len)
{
    StringBuilder_appendJsonElem(sb, zPropName, -1);
    StringBuilder_appendRaw(sb, ":{", 2);

    int i;
    bool appendComma = false;
    for (i = 0; i < len; i++)
    {
        _buildMetadataRef(sb, zProps[i], &aMeta[i], &appendComma);
        appendComma = true;
    }

    StringBuilder_appendRaw(sb, "}", 1);
}

static void
_buildMixinRef(const char *zKey, const sqlite3_int64 index, struct flexi_class_ref_def *pRef,
               const var collection, struct _BuildInternalClassDefJSON_Ctx *ctx, bool *bStop)
{
    UNUSED_PARAM(zKey);
    UNUSED_PARAM(bStop);
    UNUSED_PARAM(collection);

    if (index > 0)
        StringBuilder_appendRaw(&ctx->sb, ",", 1);
    StringBuilder_appendRaw(&ctx->sb, "{", 1);

    _internalAppendClassDefRef(&ctx->sb, pRef);

    StringBuilder_appendRaw(&ctx->sb, "}", 1);
}

/*
 * Build class definition JSON from pClassDef.
 * Uses internal IDs (e.g. property IDs) instead of names.
 * Build output is placed into pzOutput in the format ('{properties: {1: {...}, 2: {...}}}')
 */
static int
_buildInternalClassDefJSON(struct flexi_ClassDef_t *pClassDef, char **pzOutput)
{
    int result;

    struct _BuildInternalClassDefJSON_Ctx ctx;
    ctx.pClassDef = pClassDef;
    StringBuilder_init(&ctx.sb);

    StringBuilder_appendRaw(&ctx.sb, "{properties:{", -1);

    // 'properties'
    HashTable_each(&pClassDef->propsByName, (void *) _buildPropDefJSON, &ctx);
    StringBuilder_appendRaw(&ctx.sb, "},", -1);

    // 'fullTextIndexing'
    const char *azFtsNames[] = {"X1", "X2", "X3", "X4", "X5"};
    _buildMetaDataRefArray(&ctx.sb, "fullTextIndexing", pClassDef->aFtsProps, azFtsNames,
                           ARRAY_LEN(pClassDef->aFtsProps));

    // 'mixins'
    Array_each(pClassDef->aMixins, (void *) _buildMixinRef, &ctx);

    // 'rangeIndexing'
    const char *azRngNames[] = {"A0", "A1", "B0", "B1", "C0", "C1", "D0", "D1", "E0", "E1"};
    _buildMetaDataRefArray(&ctx.sb, "rangeIndexing", pClassDef->aRangeProps, azRngNames,
                           ARRAY_LEN(pClassDef->aRangeProps));

    // 'specialProperties'
    const char *azSpecNames[] = {"uid", "name", "description", "code", "nonUniqueId", "createTime", "updateTime",
                                 "autoUuid", "autoShortId"};
    _buildMetaDataRefArray(&ctx.sb, "specialProperties", pClassDef->aSpecProps, azSpecNames,
                           ARRAY_LEN(pClassDef->aSpecProps));

    StringBuilder_appendRaw(&ctx.sb, "}", 1);

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    StringBuilder_clear(&ctx.sb);

    return result;
}

/*
 * Create new class record in the database. Data field is not saved at this point yet
 */
static int _create_class_record(struct flexi_Context_t *pCtx, const char *zClassName, sqlite3_int64 *plClassID)
{
    int result;
    if (!pCtx->pStmts[STMT_INS_CLS])
    {
        CHECK_STMT_PREPARE(pCtx->db, "insert into [.classes] (NameID) values (:1);", &pCtx->pStmts[STMT_INS_CLS]);
    }
    CHECK_CALL(sqlite3_reset(pCtx->pStmts[STMT_INS_CLS]));
    sqlite3_int64 lClassNameID;
    CHECK_CALL(flexi_Context_insertName(pCtx, zClassName, &lClassNameID));
    CHECK_CALL(sqlite3_bind_int64(pCtx->pStmts[STMT_INS_CLS], 1, lClassNameID));
    CHECK_STMT_STEP(pCtx->pStmts[STMT_INS_CLS]);
    if (result != SQLITE_DONE)
        goto ONERROR;

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
    CHECK_CALL(sqlite3_bind_text(pStmt, 1, zClassDefJson, -1, NULL));
    CHECK_STMT_STEP(pStmt);
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
    CHECK_CALL(sqlite3_bind_text(pStmt, 1, zClassDefJson, -1, NULL));
    CHECK_STMT_STEP(pStmt);
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
    CHECK_CALL(sqlite3_bind_text(pStmt, 1, zClassDefJson, -1, NULL));
    CHECK_STMT_STEP(pStmt);
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
        CHECK_STMT_STEP(pStmt);
        if (result == SQLITE_DONE)
            break;

        if (pClassDef->aMixins == NULL)
            pClassDef->aMixins = Array_new(sizeof(struct flexi_class_ref_def), (void *) flexi_class_ref_def_dispose);

        struct flexi_class_ref_def *mixin = Array_append(pClassDef->aMixins);
        if (!mixin)
        {
            result = SQLITE_NOMEM;
            goto ONERROR;
        }

        flexi_class_ref_def_init(mixin);

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
            CHECK_STMT_STEP(pRulesStmt);
            if (result != SQLITE_ROW)
                break;

            struct flexi_class_ref_rule *rule = Array_append(&mixin->rules);
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
        Array_dispose(pClassDef->aMixins);
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
        struct flexi_PropDef_t *pProp = flexi_prop_def_new(pClassDef->lClassID);
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

        assert(pProp->name.name != NULL);

        HashTable_set(&pClassDef->propsByName, (DictionaryKey_t) {.pKey=pProp->name.name}, pProp);
    }

    if (result != SQLITE_DONE)
        goto ONERROR;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:
    sqlite3_free(zPropDefJson);

    EXIT:

    return result;
}

static int _parseClassDefAux(struct flexi_ClassDef_t *pClassDef, const char *zClassDefJson)
{
    int result;
    CHECK_CALL(_parseFullTextProperties(pClassDef, zClassDefJson));
    CHECK_CALL(_parseMixins(pClassDef, zClassDefJson));
    CHECK_CALL(_parseRangeProperties(pClassDef, zClassDefJson));
    CHECK_CALL(_parseSpecialProperties(pClassDef, zClassDefJson));

    goto EXIT;
    ONERROR:
    EXIT:
    return result;
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
    HashTable_init(&result->propsByName, DICT_STRING, (void *) flexi_prop_def_free);
    return result;
}

/// @brief Creates a new Flexilite class, based on name and JSON definition.
/// Class must not exist
/// @param zClassName
/// @param zClassDef
/// @param bCreateVTable
/// @param pzError
/// @return
int flexi_ClassDef_create(struct flexi_Context_t *pCtx, const char *zClassName,
                          const char *zClassDef, bool bCreateVTable,
                          const char **pzError)
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
        *pzError = sqlite3_mprintf("Class [%s] already exists", zClassName);
        goto ONERROR;
    }

    if (!db_validate_name(zClassName))
    {
        result = SQLITE_ERROR;
        *pzError = sqlite3_mprintf("Invalid class name [%s]", zClassName);
        goto ONERROR;
    }

    // Create (non-complete) record in .classes table
    CHECK_CALL(_create_class_record(pCtx, zClassName, &lClassID));

    CHECK_CALL(_flexi_ClassDef_applyNewDef(pCtx, lClassID, zClassDef, bCreateVTable, INVALID_DATA_ABORT, pzError));

    result = SQLITE_OK;

    goto EXIT;

    ONERROR:
    // Release resources because of errors (catch)

    EXIT:

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

    //    sqlite3_free(sbClassDefJSON);

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
        CHECK_CALL(sqlite3_exec(db, zSQL, NULL, NULL, (char **) &zError));
    }
    else
    {
        void *pCtx = sqlite3_user_data(context);
        CHECK_CALL(flexi_ClassDef_create(pCtx, zClassName, zClassDef, bCreateVTable, &zError));
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
    CHECK_CALL(flexi_class_alter(pCtx, zClassName, zNewClassDef, eValidationMode, bCreateVTable, &zError));

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

int flexi_class_drop(struct flexi_Context_t *pCtx, sqlite3_int64 lClassID, int softDelete,
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

    CHECK_CALL(flexi_class_drop(pCtx, lClassID, softDel, &zError));
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
    CHECK_CALL(flexi_Context_insertName(pCtx, zNewName, &lNewNameID));

    // TODO Move to prepared statements
    if (!pCtx->pStmts[STMT_CLS_RENAME])
    {
        const char *zErrMsg;
        sqlite3_stmt *pStmt;
        CHECK_STMT_PREPARE(pCtx->db, "update [.classes] set NameID = :1 "
                "where ClassID = :2;", &pCtx->pStmts[STMT_CLS_RENAME]);
    }
    CHECK_CALL(sqlite3_reset(pCtx->pStmts[STMT_CLS_RENAME]));
    sqlite3_bind_int64(pCtx->pStmts[STMT_CLS_RENAME], 1, lNewNameID);
    sqlite3_bind_int64(pCtx->pStmts[STMT_CLS_RENAME], 2, iOldClassID);
    CHECK_STMT_STEP(pCtx->pStmts[STMT_CLS_RENAME]);
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

            Array_dispose(self->aMixins);

            for (int ii = 0; ii < ARRAY_LEN(self->aSpecProps); ii++)
            {
                flexi_metadata_ref_free(&self->aSpecProps[ii]);
            }

            for (int ii = 0; ii < ARRAY_LEN(self->aFtsProps); ii++)
            {
                flexi_metadata_ref_free(&self->aFtsProps[ii]);
            }

            for (int ii = 0; ii < ARRAY_LEN(self->aRangeProps); ii++)
            {
                flexi_metadata_ref_free(&self->aRangeProps[ii]);
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
    CHECK_CALL(sqlite3_declare_vtab(pClassDef->pCtx->db, sbClassDef));

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    sqlite3_free(sbClassDef);

    return result;
}


/*
 * Parses class definition JSON into classDef structure (which is supposed to be already allocated and zeroed)
 */
int flexi_ClassDef_parse(struct flexi_ClassDef_t *pClassDef,
                         const char *zClassDefJson, const char **pzErr)
{
    UNUSED_PARAM(pzErr);

    int result;

    sqlite3_stmt *pStmt = NULL;

    // Load properties
    char *zPropSql = "select key as Name, value as Definition from json_each(:1, '$.properties');";
    CHECK_STMT_PREPARE(pClassDef->pCtx->db, zPropSql, &pStmt);
    CHECK_CALL(sqlite3_bind_text(pStmt, 1, zClassDefJson, -1, NULL));
    CHECK_CALL(_parseProperties(pClassDef, pStmt, 0, 1, -1, -1, -1));

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
 * Loads class definition from [.classes] and [flexi_prop] tables
 * into ppVTab (casted to flexi_ClassDef_t).
 * Used by Create and Connect methods
 */
int flexi_ClassDef_load(struct flexi_Context_t *pCtx, sqlite3_int64 lClassID, struct flexi_ClassDef_t **pClassDef,
                        const char **pzErr)
{
    int result;
    char *zClassDefJson = NULL;

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
            "Data as Definition " // 5
            "from [.classes] "
            "where ClassID = :1;";
    CHECK_STMT_PREPARE(pCtx->db, zGetClassSQL, &pGetClassStmt);
    sqlite3_bind_int64(pGetClassStmt, 1, lClassID);
    result = sqlite3_step(pGetClassStmt);
    if (result == SQLITE_DONE)
        // No class found. Return error
    {
        result = SQLITE_NOTFOUND;
        if (pzErr)
            *pzErr = sqlite3_mprintf("Cannot find Flexilite class with ID [%ld]", lClassID);
        goto ONERROR;
    }

    if (result != SQLITE_ROW)
        goto ONERROR;

    (*pClassDef)->lClassID = sqlite3_column_int64(pGetClassStmt, 0);
    (*pClassDef)->name.id = sqlite3_column_int64(pGetClassStmt, 1);
    (*pClassDef)->bSystemClass = (bool) sqlite3_column_int(pGetClassStmt, 2);
    (*pClassDef)->xCtloMask = sqlite3_column_int(pGetClassStmt, 3);

    // TODO Temp
    char *zClassDef = NULL;
    getColumnAsText(&zClassDef, pGetClassStmt, 5);

    //    CHECK_CALL(getColumnAsText(&(*pClassDef)->zHash, pGetClassStmt, 4));

    // Load properties from flexi_prop
    if (!pCtx->pStmts[STMT_LOAD_CLS_PROP])
    {
        CHECK_STMT_PREPARE(pCtx->db, "select "
                "PropertyID," // 0
                "Class, " // 1
                "NameID, " // 2
                "Property," // 3
                "ctlv," // 4
                "ctlvPlan," // 5
                "Definition" // 6
                " from [flexi_prop] where ClassID=:1",
                           &pCtx->pStmts[STMT_LOAD_CLS_PROP]);
    }
    CHECK_CALL(sqlite3_reset(pCtx->pStmts[STMT_LOAD_CLS_PROP]));
    CHECK_CALL(sqlite3_bind_int64(pCtx->pStmts[STMT_LOAD_CLS_PROP], 1, lClassID));
    CHECK_CALL(_parseProperties(*pClassDef, pCtx->pStmts[STMT_LOAD_CLS_PROP], 3, 6, 2, 4, 5));

    CHECK_CALL(getColumnAsText(&zClassDefJson, pGetClassStmt, 5));
    CHECK_CALL(_parseClassDefAux(*pClassDef, zClassDefJson));

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:
    if (*pClassDef)
    {
        flexi_ClassDef_free(*pClassDef);
        *pClassDef = NULL;
    }
    *pzErr = sqlite3_errmsg(pCtx->db);

    EXIT:
    if (pGetClassStmt)
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
        CHECK_CALL(sqlite3_bind_value(pStmt, 1, sqlite3_value_dup(argv[0])));

        while ((result = sqlite3_step(pStmt)) == SQLITE_ROW)
        {
            sqlite3_free(zClassDef);
            zClassDef = NULL;
            sqlite3_free(zClassName);
            zClassName = NULL;

            CHECK_CALL(getColumnAsText(&zClassDef, pStmt, 0));
            CHECK_CALL(getColumnAsText(&zClassName, pStmt, 1));

            CHECK_CALL(flexi_ClassDef_create(pCtx, zClassName, zClassDef, bCreateVTable, &zErr));
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
    return result;
}

