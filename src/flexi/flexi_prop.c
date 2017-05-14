//
// Created by slanska on 2016-04-28.
//

#include <sqlite3ext.h>
#include "flexi_prop.h"
#include "../misc/regexp.h"
#include "../typings/DBDefinitions.h"
#include "../util/StringBuilder.h"

int flexi_prop_create_func(
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

int flexi_prop_alter_func(
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

int flexi_prop_drop_func(
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

int flexi_prop_rename_func(
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
 * Allocates new instance of class prop definition
 * Sets class ID, ref count to 1 and status 'ADDED'
 */
struct flexi_PropDef_t *flexi_PropDef_new(sqlite3_int64 lClassID)
{
    struct flexi_PropDef_t *result = sqlite3_malloc(sizeof(struct flexi_PropDef_t));
    if (result)
    {
        memset(result, 0, sizeof(struct flexi_PropDef_t));
        result->lClassID = lClassID;
        result->nRefCount = 1;
        result->eChangeStatus = CHNG_STATUS_ADDED;
    }
    return result;
}

/// @brief
/// @param pProp
/// @param zPropName
/// @param zPropDefJson
/// @return
int flexi_prop_def_parse(struct flexi_PropDef_t *pProp, const char *zPropName, const char *zPropDefJson)
{
    assert(pProp && pProp->lClassID != 0 && pProp->pCtx);

    int result;

    struct flexi_Context_t *pCtx = pProp->pCtx;
    if (!pCtx->pStmts[STMT_PROP_PARSE])
    {
        const char *zPropParseSQL = "select "
                "coalesce(json_extract(:1, '$.index'), 'none') as prop_index," // 0
                "json_extract(:1, '$.subType') as subType," // 1
                "coalesce(json_extract(:1, '$.minOccurences'), 0) as minOccurrences," // 2
                "coalesce(json_extract(:1, '$.maxOccurences'), 1) as maxOccurrences," // 3
                "coalesce(json_extract(:1, '$.rules.type'), 'text') as prop_type," // 4
                "coalesce(json_extract(:1, '$.noTrackChanges'), 0) as noTrackChanges," // 5
                "json_extract(:1, '$.enumDef')as enumDef," // 6
                "json_extract(:1, '$.refDef') as refDef," // 7
                "json_extract(:1, '$.$renameTo') as renameTo," // 8
                "coalesce(json_extract(:1, '$.$drop'), 0) as prop_drop," // 9
                "coalesce(json_extract(:1, '$.rules.maxLength'), 0) as maxLength," // 10
                "coalesce(json_extract(:1, '$.rules.minValue'), 0) as minValue," // 11
                "coalesce(json_extract(:1, '$.rules.maxValue'), 0) as maxValue," // 12
                "coalesce(json_extract(:1, '$.rules.regex'), 0) as regex," // 13
                "coalesce(json_extract(:1, '$.enumDef.$id'), 0) as enumDef_id," // 14
                "json_extract(:1, '$.enumDef.$name') as enumDef_name" // 15
        ;
        CHECK_STMT_PREPARE(pCtx->db, zPropParseSQL, &pCtx->pStmts[STMT_PROP_PARSE]);
    }

    sqlite3_stmt *st = pCtx->pStmts[STMT_PROP_PARSE];

    CHECK_CALL(sqlite3_reset(st));
    CHECK_CALL(sqlite3_bind_text(st, 1, zPropDefJson, -1, NULL));
    if ((result = sqlite3_step(st)) == SQLITE_ROW)
    {
        CHECK_CALL(getColumnAsText(&pProp->zIndex, st, 0));
        CHECK_CALL(getColumnAsText(&pProp->zSubType, st, 1));
        pProp->minOccurences = sqlite3_column_int(st, 2);
        pProp->maxOccurences = sqlite3_column_int(st, 3);
        CHECK_CALL(getColumnAsText(&pProp->zType, st, 4));
        pProp->bNoTrackChanges = (bool) sqlite3_column_int(st, 5);
        CHECK_CALL(getColumnAsText(&pProp->zEnumDef, st, 6));
        CHECK_CALL(getColumnAsText(&pProp->zRefDef, st, 7));

        CHECK_CALL(getColumnAsText(&pProp->zRenameTo, st, 8));
        if (sqlite3_column_int(st, 9) == 1)
            pProp->eChangeStatus = CHNG_STATUS_DELETED;
        pProp->maxLength = sqlite3_column_int(st, 10);
        pProp->minValue = sqlite3_column_int(st, 11);
        pProp->maxValue = sqlite3_column_int(st, 12);
        CHECK_CALL(getColumnAsText(&pProp->regex, st, 13));

        // Check enumDef
        if (pProp->zEnumDef)
        {
            flexi_MetadataRef_t enumName;
            enumName.id = sqlite3_column_int64(st, 14);
            CHECK_CALL(getColumnAsText(&enumName.name, st, 15));

            // TODO Get items
        }

        // Check refDef
        if (pProp->zRefDef)
        {
            // classRef
            // dynamic
            // rules
            // reverseProperty
            // autoFetchLimit
            // autoFetchDepth
            // rule
        }
    }

    if (result != SQLITE_ROW && result != SQLITE_DONE && result != SQLITE_OK)
        goto ONERROR;

    result = SQLITE_OK;

    goto EXIT;
    ONERROR:
    EXIT:
    return result;
}

/// @brief
/// @param pProp
/// @param pzPropDefJson
/// @return
int flexi_prop_def_stringify(struct flexi_PropDef_t *pProp, char **pzPropDefJson)
{
    return 0;
}

/// @brief
/// @param pOldDef
/// @param pNewDef
/// @param piResult
/// @param pzError
/// @return
int flexi_prop_def_get_changes_needed(struct flexi_PropDef_t *pOldDef,
                                      struct flexi_PropDef_t *pNewDef, int *piResult,
                                      const char **pzError)
{
    return 0;
}

int flexi_prop_to_ref_func(
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

int flexi_ref_to_prop_func(
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
 *
 */
void flexi_PropDef_free(struct flexi_PropDef_t *prop)
{
    assert(prop);

    if (--prop->nRefCount == 0)
    {
        sqlite3_value_free(prop->defaultValue);

        sqlite3_free(prop->regex);
        if (prop->pRegexCompiled)
            re_free(prop->pRegexCompiled);

        sqlite3_free(prop->name.name);
        flexi_RefDef_free(prop->pRefDef);
        flexi_enum_def_free(prop->pEnumDef);

        sqlite3_free(prop->zRefDef);
        sqlite3_free(prop->zIndex);
        sqlite3_free(prop->zSubType);
        sqlite3_free(prop->zRenameTo);
        sqlite3_free(prop->zType);

        sqlite3_free(prop);
    }
}

void flexi_RefDef_free(Flexi_ClassRefDef_t *self)
{
    if (self)
    {
        Array_clear(&self->rules);
        flexi_MetadataRef_free(&self->classRef);
        flexi_MetadataRef_free(&self->dynSelectorProp);
        sqlite3_free(self);
    }
}

void flexi_enum_def_free(flexi_enum_def *p)
{
    if (p)
    {
        // TODO
        sqlite3_free(p);
    }
}

int flexi_PropDef_validateValue(struct flexi_PropDef_t *prop, flexi_ClassDef_t *pClassDef, sqlite3_value *value)
{
    int result = SQLITE_ERROR;

    // Required
    if (prop->minOccurences > 0 && sqlite3_value_type(value) == SQLITE_NULL)
    {
        flexi_Context_setError(pClassDef->pCtx, result,
                               sqlite3_mprintf("Column %s is required", prop->name.name));
        pClassDef->base.zErrMsg = pClassDef->pCtx->zLastErrorMessage;
        goto ONERROR;
    }

    int t = sqlite3_value_type(value);
    switch (prop->type)
    {
        case PROP_TYPE_BINARY:
            // Do nothing?
            break;

        case PROP_TYPE_DATETIME:
        {
            // Convert from string?
            break;
        }

        case PROP_TYPE_ENUM:
        {
            // Check if value is in the list
            // TODO
            break;
        }

        case PROP_TYPE_DECIMAL:
        case PROP_TYPE_INTEGER:
        {
            // Check range
            sqlite3_int64 i = sqlite3_value_int64(value);
            double d = (double) i;

            // Check minValue, maxValue
            if (d < prop->minValue || d > prop->maxValue)
            {
                pClassDef->base.zErrMsg = "Value is not within range";
                goto ONERROR;
            }

            break;
        }

        case PROP_TYPE_NUMBER:
        {
            double d = sqlite3_value_double(value);
            if (t != SQLITE_FLOAT)
            {
                // TODO
                t = sqlite3_value_numeric_type(value);

            }

            // Check minValue, maxValue
            if (d < prop->minValue || d > prop->maxValue)
            {
                pClassDef->base.zErrMsg = "Value is not within range";
                goto ONERROR;
            }
        }
            break;

        case PROP_TYPE_NAME:
        case PROP_TYPE_TEXT:
        {
            const unsigned char *str = NULL;

            // for NAME, check if value type is integer and there is name in database
            // with matching NameID. In this case,

            // maxLength, if applicable
            if (prop->maxLength > 0)
            {
                // TODO For NAME get actual value and compare
                str = sqlite3_value_text(value);
                int len = get_utf8_len(str);
                if (len > prop->maxLength)
                {
                    pClassDef->base.zErrMsg = "Too long value for column %s";
                    goto ONERROR;
                }
            }

            // regex, if applicable
            if (prop->regex)
            {
                if (str == NULL)
                    str = sqlite3_value_text(value);
                CHECK_CALL(re_match(prop->pRegexCompiled, str, -1));
            }
        }

            break;

        default:
            break;
    }

    result = SQLITE_OK;
    goto EXIT;
    ONERROR:

    EXIT:
    return result;
}
