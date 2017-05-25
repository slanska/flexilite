//
// Created by slanska on 2017-04-16.
//

#include "../project_defs.h"
#include "flexi_class.h"
#include "../util/StringBuilder.h"

/*
 * Internally used structure for building class definition JSON
 */
struct _BuildInternalClassDefJSON_Ctx
{
    /*
     * Class definition object
     */
    struct flexi_ClassDef_t *pClassDef;

    /*
     * Built class def JSON. Internal representation, with IDs instead of property names
     */
    StringBuilder_t sb;

    /*
     * Compiled statement to extract property attributes
     */
    sqlite3_stmt *pParsePropStmt;

    /*
     * Result of entire operation
     */
    int result;

    /*
     * Input class definition JSON
     */
    const char *zInClassDef;
};

/*
 * Append a metadata ref to JSON
 */
static void
_internalAppendMetaDataRef(struct _BuildInternalClassDefJSON_Ctx *ctx,
                           flexi_MetadataRef_t *ref, bool bProp)
{
    char zID[30];
    int result;

    StringBuilder_t *sb = &ctx->sb;

    if (ref->id == 0 && ref->name != NULL)
    {
        if (bProp)
        {
            result = flexi_Context_getPropIdByClassIdAndName(ctx->pClassDef->pCtx, ctx->pClassDef->lClassID, ref->name,
                                                             &ref->id);
        }
        else
        {
            result = flexi_Context_getClassIdByName(ctx->pClassDef->pCtx, ref->name, &ref->id);
        }

        // TODO Temp
        assert(result == SQLITE_OK);
    }

    StringBuilder_appendJsonElem(sb, "$id", -1);
    StringBuilder_appendRaw(sb, ":", 1);
    sprintf(zID, "%"
            PRId64, ref->id);
    StringBuilder_appendJsonElem(sb, zID, -1);

    // If ID is 0, it means that name is not yet resolved. Store name too for future processing
    if (ref->id == 0)
    {
        StringBuilder_appendRaw(sb, ",", 1);
        StringBuilder_appendJsonElem(sb, "$name", -1);
        StringBuilder_appendRaw(sb, ":", 1);
        StringBuilder_appendJsonElem(sb, ref->name, -1);
    }
}

/*
 * Appends class data reference definition to the given JSON string builder sb
 */
static void
_buildMetadataRef(struct _BuildInternalClassDefJSON_Ctx *ctx, const char *zAttrName, flexi_MetadataRef_t *ref,
                  bool *pbPrependComma, bool bProp)
{
    StringBuilder_t *sb = &ctx->sb;

    if (ref->id != 0 || ref->name != NULL)
    {
        if (pbPrependComma != NULL)
        {
            if (*pbPrependComma)
            {
                StringBuilder_appendRaw(sb, ",", 1);
            }
            else
            {
                *pbPrependComma = true;
            }
        }
        StringBuilder_appendJsonElem(sb, zAttrName, -1);
        StringBuilder_appendRaw(sb, ":{", 2);

        _internalAppendMetaDataRef(ctx, ref, bProp);

        StringBuilder_appendRaw(sb, "}", 1);
    }
}

/*
 * Appends individual dynamic rule to JSON
 */
static void _appendClassRefDynRule(const char *zKey, const sqlite3_int64 index,
                                   struct flexi_ClassRefRule *pData,
                                   const var collection, struct _BuildInternalClassDefJSON_Ctx *ctx, bool *bStop)
{
    UNUSED_PARAM(zKey);
    UNUSED_PARAM(collection);
    UNUSED_PARAM(bStop);

    StringBuilder_t *sb = &ctx->sb;

    if (index > 0)
        StringBuilder_appendRaw(sb, ",", 1);
    StringBuilder_appendRaw(sb, "{", 1);
    StringBuilder_appendJsonElem(sb, "regex", -1);
    StringBuilder_appendJsonElem(sb, pData->regex, -1);
    StringBuilder_appendRaw(sb, ",", 1);
    _buildMetadataRef(ctx, "classRef", &pData->classRef, NULL, false);
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
_internalAppendClassDefRef(struct _BuildInternalClassDefJSON_Ctx *ctx, Flexi_ClassRefDef_t *classRefDef)
{
    StringBuilder_t *sb = &ctx->sb;
    _buildMetadataRef(ctx, "classRef", &classRefDef->classRef, NULL, NULL);

    if (classRefDef->dynSelectorProp.id != 0 || classRefDef->dynSelectorProp.name != NULL)
    {
        StringBuilder_appendRaw(sb, ",", 1);
        StringBuilder_appendJsonElem(sb, "dynamic", -1);
        StringBuilder_appendRaw(sb, ":{", 2);
        _buildMetadataRef(ctx, "selectorProp", &classRefDef->dynSelectorProp, NULL, NULL);

        StringBuilder_appendRaw(sb, ",{", 2);
        StringBuilder_appendJsonElem(sb, "rules", -1);
        Array_each(&classRefDef->rules, (void *) _appendClassRefDynRule, ctx);

        StringBuilder_appendRaw(sb, "}}", 2);
    }
}

/*
 * Appends class ref def (mixin class ref)

 */
static void
_buildClassDefRef(struct _BuildInternalClassDefJSON_Ctx *ctx, const char *RefPropName, Flexi_ClassRefDef_t *classRefDef,
                  bool *pbPrependComma)
{
    UNUSED_PARAM(RefPropName);

    StringBuilder_t *sb = &ctx->sb;

    if (pbPrependComma != NULL)
    {
        if (*pbPrependComma)
        {
            StringBuilder_appendRaw(sb, ",", 1);
        }
        else
        {
            *pbPrependComma = true;
        }
    }

    StringBuilder_appendRaw(sb, "{", 1);
    _internalAppendClassDefRef(ctx, classRefDef);
    StringBuilder_appendRaw(sb, "}", 1);
}

static int
_copyPropJsonAttr(struct _BuildInternalClassDefJSON_Ctx *ctx, const char *zPropName, const char *zAttr,
                  bool *pbPrependComma)
{
    int result;
    char *zPath = NULL;
    char *zVal = NULL;

    zPath = sqlite3_mprintf("$.properties.%s.%s", zPropName, zAttr);
    CHECK_SQLITE(ctx->pClassDef->pCtx->db, sqlite3_reset(ctx->pParsePropStmt));
    CHECK_SQLITE(ctx->pClassDef->pCtx->db, sqlite3_bind_text(ctx->pParsePropStmt, 1, ctx->zInClassDef, -1, NULL));
    CHECK_SQLITE(ctx->pClassDef->pCtx->db, sqlite3_bind_text(ctx->pParsePropStmt, 2, zPath, -1, NULL));
    result = sqlite3_step(ctx->pParsePropStmt);
    if (result == SQLITE_ROW)
    {
        result = SQLITE_OK;
        if (sqlite3_column_type(ctx->pParsePropStmt, 0) != SQLITE_NULL)
        {
            if (pbPrependComma != NULL)
            {
                if (*pbPrependComma)
                    StringBuilder_appendRaw(&ctx->sb, ",", 1);
                else *pbPrependComma = true;
            }

            StringBuilder_appendJsonElem(&ctx->sb, zAttr, -1);
            StringBuilder_appendRaw(&ctx->sb, ":", 1);

            CHECK_CALL(getColumnAsText(&zVal, ctx->pParsePropStmt, 0));
            if (strlen(zVal) > 0 && (*zVal == '{' || *zVal == '['))
                StringBuilder_appendRaw(&ctx->sb, zVal, -1);
            else StringBuilder_appendJsonElem(&ctx->sb, zVal, -1);
        }
    }
    else
        if (result != SQLITE_DONE)
            ctx->result = result;

    goto EXIT;

    ONERROR:

    EXIT:
    sqlite3_free(zVal);
    sqlite3_free(zPath);
    return result;
}

/*
 * Iterator function for generating internal property definition JSON
 */
static void
_buildPropDefJSON(const char *zPropName, const sqlite3_int64 index, struct flexi_PropDef_t *prop,
                  const var collection, struct _BuildInternalClassDefJSON_Ctx *ctx, bool *bStop)
{
    UNUSED_PARAM(index);
    UNUSED_PARAM(collection);

    int result;
    bool bPrependComma = false;

    if (index > 0)
    {
        StringBuilder_appendRaw(&ctx->sb, ",", 1);
    }
    char zPropID[30];
    sprintf(zPropID, "%"
            PRId64, prop->iPropID);
    StringBuilder_appendJsonElem(&ctx->sb, zPropID, -1);
    StringBuilder_appendRaw(&ctx->sb, ":{", 2);

    if (ctx->pParsePropStmt == NULL)
    {
        CHECK_STMT_PREPARE(ctx->pClassDef->pCtx->db, "select json_extract(:1, :2) as val;", &ctx->pParsePropStmt);
    }

    CHECK_CALL(_copyPropJsonAttr(ctx, zPropName, "rules", &bPrependComma));
    CHECK_CALL(_copyPropJsonAttr(ctx, zPropName, "index", &bPrependComma));
    CHECK_CALL(_copyPropJsonAttr(ctx, zPropName, "defaultValue", &bPrependComma));
    CHECK_CALL(_copyPropJsonAttr(ctx, zPropName, "noTrackChanges", &bPrependComma));

    // refDef
    if (strcmp(prop->zType, "reference") == 0)
        // TODO
        if (prop->pRefDef != NULL)
        {
            StringBuilder_appendRaw(&ctx->sb, ",", 1);
            StringBuilder_appendJsonElem(&ctx->sb, "refDef", -1);
            StringBuilder_appendRaw(&ctx->sb, ":", 1);
            _internalAppendClassDefRef(ctx, prop->pRefDef);

        }

    // enumDef
    if (strcmp(prop->zType, "enum") == 0)
    {
        StringBuilder_appendRaw(&ctx->sb, ",", 1);
        StringBuilder_appendJsonElem(&ctx->sb, "enumDef", -1);
        StringBuilder_appendRaw(&ctx->sb, ":", 1);
        _internalAppendMetaDataRef(ctx, &prop->enumDef, false);

        // TODO enum items

    }

    StringBuilder_appendRaw(&ctx->sb, "}", 1);

    goto EXIT;

    ONERROR:
    *bStop = false;
    ctx->result = result;

    // TODO temp
    printf("Error: %s\n", sqlite3_errmsg(ctx->pClassDef->pCtx->db));

    EXIT:

    return;
}

/*
 * Appends array of metadata references to string build sb as zName object property.
 * len defines number of items.
 * aMeta - array of metadata refs
 * zProps - names for items (number should be equal to len)
 */
static void
_buildMetaDataRefArray(struct _BuildInternalClassDefJSON_Ctx *ctx, const char *zPropName, flexi_MetadataRef_t *aMeta,
                       const char *zProps[], int len, bool bProp)
{
    StringBuilder_t *sb = &ctx->sb;
    if (len > 0)
    {
        StringBuilder_appendJsonElem(sb, zPropName, -1);
        StringBuilder_appendRaw(sb, ":{", 2);

        int i;
        bool bPrependComma = false;
        for (i = 0; i < len; i++)
            _buildMetadataRef(ctx, zProps[i], &aMeta[i], &bPrependComma, bProp);

        StringBuilder_appendRaw(sb, "}", 1);
    }
}

static void
_buildMixinRef(const char *zKey, const sqlite3_int64 index, struct flexi_ClassRefDef *pRef,
               const var collection, struct _BuildInternalClassDefJSON_Ctx *ctx, bool *bStop)
{
    UNUSED_PARAM(zKey);
    UNUSED_PARAM(bStop);
    UNUSED_PARAM(collection);

    if (index > 0)
        StringBuilder_appendRaw(&ctx->sb, ",", 1);
    StringBuilder_appendRaw(&ctx->sb, "{", 1);

    _internalAppendClassDefRef(ctx, pRef);

    StringBuilder_appendRaw(&ctx->sb, "}", 1);
}

/*
 * Build class definition JSON from pClassDef.
 * Uses internal IDs (e.g. property IDs) instead of names. Internal IDs are expected to be set in class definition.
 * Build output is placed into pzOutput in the format ('{properties: {1: {...}, 2: {...}}}')
 */
int flexi_buildInternalClassDefJSON(struct flexi_ClassDef_t *pClassDef, const char *zClassDef, char **pzOutput)
{
    struct _BuildInternalClassDefJSON_Ctx ctx;
    memset(&ctx, 0, sizeof(ctx));
    ctx.pClassDef = pClassDef;
    ctx.zInClassDef = zClassDef;
    StringBuilder_init(&ctx.sb);

    StringBuilder_appendRaw(&ctx.sb, "{", 1);
    StringBuilder_appendJsonElem(&ctx.sb, "properties", -1);
    StringBuilder_appendRaw(&ctx.sb, ":{", 2);

    // 'properties'
    HashTable_each(&pClassDef->propsByName, (void *) _buildPropDefJSON, &ctx);

    // 'fullTextIndexing'
    StringBuilder_appendRaw(&ctx.sb, "},", -1);
    const char *azFtsNames[] = {"X1", "X2", "X3", "X4", "X5"};
    _buildMetaDataRefArray(&ctx, "fullTextIndexing", pClassDef->aFtsProps, azFtsNames, ARRAY_LEN(pClassDef->aFtsProps),
                           true);

    // 'mixins'
    if (pClassDef->aMixins != NULL)
    {
        StringBuilder_appendRaw(&ctx.sb, "},", -1);
        Array_each(pClassDef->aMixins, (void *) _buildMixinRef, &ctx);
    }

    // 'rangeIndexing'
    StringBuilder_appendRaw(&ctx.sb, ",", 1);
    const char *azRngNames[] = {"A0", "A1", "B0", "B1", "C0", "C1", "D0", "D1", "E0", "E1"};
    _buildMetaDataRefArray(&ctx, "rangeIndexing", pClassDef->aRangeProps, azRngNames, ARRAY_LEN(pClassDef->aRangeProps),
                           true);

    // 'specialProperties'
    StringBuilder_appendRaw(&ctx.sb, ",", 1);
    const char *azSpecNames[] = {"uid", "name", "description", "code", "nonUniqueId", "createTime", "updateTime",
                                 "autoUuid", "autoShortId"};
    _buildMetaDataRefArray(&ctx, "specialProperties", pClassDef->aSpecProps, azSpecNames,
                           ARRAY_LEN(pClassDef->aSpecProps), true);

    StringBuilder_appendRaw(&ctx.sb, "}", 1);

    *pzOutput = ctx.sb.zBuf;
    ctx.sb.bStatic = true; // To prevent freeing result buffer

    StringBuilder_clear(&ctx.sb);
    sqlite3_finalize(ctx.pParsePropStmt);

    return SQLITE_OK;
}
