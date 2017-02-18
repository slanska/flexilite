//
// Created by slanska on 2016-04-28.
//

#include <sqlite3ext.h>
#include <assert.h>
#include "flexi_prop.h"
#include "flexi_db_ctx.h"
#include "../common/common.h"

void flexi_prop_create_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
) {}

void flexi_prop_alter_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
) {}

void flexi_prop_drop_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
) {}

void flexi_prop_rename_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
) {}

int flexi_prop_def_parse(struct flexi_prop_def *pProp, const char *zPropName, const char *zPropDefJson) {
    assert(pProp && pProp->lClassID && pProp->pCtx);

    const char *zPropParseSQL = "select "
            "coalesce(json_extract(:1, '$.index'), 'none') as index," // 0
            "coalesce(json_extract(:1, '$.subType'), 'none') as index," // 1
            "coalesce(json_extract(:1, '$.minOccurences'), 'none') as index," // 2
            "coalesce(json_extract(:1, '$.maxOccurences'), 'none') as index," // 3
            "coalesce(json_extract(:1, '$.rules.type'), 'text') as type," // 4
            "coalesce(json_extract(:1, '$.noTrackChanges'), 0) as indexed," // 5
            "coalesce(json_extract(:1, '$.enumDef'), 0) as indexed," // 6
//    enumDef
//    refDef
//    $renameTo
//    $drop
//    rules.maxLength
//    rules.minValue
//    rules.maxValue
//    rules.regex
    ;
    int result;

    pProp->zSrcJson = zPropDefJson;
    struct flexi_db_context *pCtx = pProp->pCtx;
    if (!pCtx->pStmts[STMT_PROP_PARSE]) {
        CHECK_CALL(sqlite3_prepare_v2(pCtx->db, zPropParseSQL, -1, &pCtx->pStmts[STMT_PROP_PARSE], NULL));
    }

    goto FINALLY;
    CATCH:
    FINALLY:
    return result;
}


void flexi_prop_to_ref_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
) {}

void flexi_ref_to_prop_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
) {}

