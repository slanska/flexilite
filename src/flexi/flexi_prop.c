//
// Created by slanska on 2016-04-28.
//

#include <sqlite3ext.h>
#include <assert.h>
#include "flexi_prop.h"
#include "flexi_db_ctx.h"
#include "../common/common.h"
#include "../misc/regexp.h"

void flexi_prop_create_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{}

void flexi_prop_alter_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{}

void flexi_prop_drop_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{}

void flexi_prop_rename_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{}

struct flexi_prop_def *flexi_prop_def_new(sqlite3_int64 lClassID)
{
    struct flexi_prop_def *result = sqlite3_malloc(sizeof(struct flexi_prop_def));
    if (result)
    {
        memset(result, 0, sizeof(struct flexi_prop_def));
        result->lClassID = lClassID;
    }
    return result;
}

int flexi_prop_def_parse(struct flexi_prop_def *pProp, const char *zPropName, const char *zPropDefJson)
{
    assert(pProp && pProp->lClassID && pProp->pCtx);

    const char *zPropParseSQL = "select "
            "coalesce(json_extract(:1, '$.index'), 'none') as index," // 0
            "coalesce(json_extract(:1, '$.subType'), NULL) as subType," // 1
            "coalesce(json_extract(:1, '$.minOccurences'), 0) as minOccurrences," // 2
            "coalesce(json_extract(:1, '$.maxOccurences'), 1) as maxOccurrences," // 3
            "coalesce(json_extract(:1, '$.rules.type'), 'text') as type," // 4
            "coalesce(json_extract(:1, '$.noTrackChanges'), 0) as noTrackChanges," // 5
            "coalesce(json_extract(:1, '$.enumDef'), NULL) as enumDef," // 6
            "coalesce(json_extract(:1, '$.refDef'), NULL) as refDef," // 7
            "coalesce(json_extract(:1, '$.$renameTo'), NULL) as renameTo," // 8
            "coalesce(json_extract(:1, '$.$drop'), 0) as drop," // 9
            "coalesce(json_extract(:1, '$.rules.maxLength'), 0) as maxLength," // 10
            "coalesce(json_extract(:1, '$.rules.minValue'), 0) as minValue," // 11
            "coalesce(json_extract(:1, '$.rules.maxValue'), 0) as maxValue," // 12
            "coalesce(json_extract(:1, '$.rules.regex'), 0) as regex" // 13
            "coalesce(json_extract(:1, '$.enumDef.$id'), 0) as enumDef_id," // 14
            "coalesce(json_extract(:1, '$.enumDef.$name'), NULL) as enumDef_name," // 15
    ;
    int result;

    struct flexi_db_context *pCtx = pProp->pCtx;
    if (!pCtx->pStmts[STMT_PROP_PARSE])
    {
        CHECK_CALL(sqlite3_prepare_v2(pCtx->db, zPropParseSQL, -1, &pCtx->pStmts[STMT_PROP_PARSE], NULL));
    }

    sqlite3_stmt *st = pCtx->pStmts[STMT_PROP_PARSE];

    CHECK_CALL(sqlite3_reset(st));
    CHECK_CALL(sqlite3_bind_text(st, 0, zPropParseSQL, -1, NULL));
    CHECK_STMT(sqlite3_step(st));
    if (result == SQLITE_DONE)
    {
        pProp->zIndex = (char *) sqlite3_column_text(st, 0);
        pProp->zSubType = (char *) sqlite3_column_text(st, 1);
        pProp->minOccurences = sqlite3_column_int(st, 2);
        pProp->maxOccurences = sqlite3_column_int(st, 3);
        pProp->zType = (char *) sqlite3_column_text(st, 4);
        pProp->bNoTrackChanges = sqlite3_column_int(st, 5);
        pProp->zEnumDef = (char *) sqlite3_column_text(st, 6);
        pProp->zRefDef = (char *) sqlite3_column_text(st, 7);
        pProp->zRenameTo = (char *) sqlite3_column_text(st, 8);
        if (sqlite3_column_int(st, 9) == 1)
            pProp->eChangeStatus = CHNG_STATUS_DELETED;
        pProp->maxLength = sqlite3_column_int(st, 10);
        pProp->minValue = sqlite3_column_int(st, 11);
        pProp->maxValue = sqlite3_column_int(st, 12);
        pProp->regex = (char *) sqlite3_column_text(st, 13);

        // Check enumDef
        if (pProp->zEnumDef)
        {
            flexi_metadata_ref enumName;
            enumName.id = sqlite3_column_int64(st, 14);
            enumName.name = (char *) sqlite3_column_text(st, 15);

            // Get items
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

    goto FINALLY;
    CATCH:
    FINALLY:
    return result;
}

int flexi_prop_def_stringify(struct flexi_prop_def *pProp, char **pzPropDefJson)
{}

int flexi_prop_def_get_changes_needed(struct flexi_prop_def *pOldDef,
                                      struct flexi_prop_def *pNewDef, int *piResult,
                                      const char **pzError)
{}

void flexi_prop_to_ref_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{}

void flexi_ref_to_prop_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{}

/*
 *
 */
void flexi_prop_def_free(struct flexi_prop_def const *prop)
{
    sqlite3_value_free(prop->defaultValue);
    sqlite3_free(prop->name.name);

    sqlite3_free(prop->regex);
    if (prop->pRegexCompiled)
        re_free(prop->pRegexCompiled);

    flexi_ref_def_free(prop->pRefDef);
    flexi_enum_def_free(prop->pEnumDef);

    sqlite3_free(prop->zIndex);
    sqlite3_free(prop->zSubType);
    sqlite3_free(prop->zRenameTo);
}

void flexi_ref_def_free(flexi_ref_def *p)
{
    if (p)
    {
        // TODO
        sqlite3_free(p);
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




