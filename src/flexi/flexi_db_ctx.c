//
// Created by slanska on 2017-02-16.
//

#include <stddef.h>
#include "flexi_db_ctx.h"
#include "flexi_class.h"
#include "../misc/regexp.h"

/*
 * Forward declarations
 */
static int flexi_prepare_db_statements(struct flexi_db_context *pCtx);

struct flexi_db_context *flexi_db_context_new(sqlite3 *db)
{
    struct flexi_db_context *result = sqlite3_malloc(sizeof(struct flexi_db_context));
    if (!result)
        return NULL;
    memset(result, 0, sizeof(struct flexi_db_context));
    result->db = db;
    HashTable_init(&result->classDefs, (void *) flexi_class_def_free);
    flexi_prepare_db_statements(result);
    return result;
}

/*
 * Gets name ID by value. Name is expected to exist
 */
int db_get_name_id(struct flexi_db_context *pCtx,
                   const char *zName, sqlite3_int64 *pNameID)
{
    if (pNameID)
    {
        sqlite3_stmt *p = pCtx->pStmts[STMT_SEL_NAME_ID];
        assert(p);
        sqlite3_reset(p);
        sqlite3_bind_text(p, 1, zName, -1, NULL);
        int stepRes = sqlite3_step(p);
        if (stepRes != SQLITE_ROW)
            return stepRes;

        *pNameID = sqlite3_column_int64(p, 0);
    }

    return SQLITE_OK;
}

/*
 * Finds property ID by its class ID and name ID
 */
int db_get_prop_id_by_class_and_name
        (struct flexi_db_context *pCtx,
         sqlite3_int64 lClassID, sqlite3_int64 lPropNameID, sqlite3_int64 *plPropID)
{
    assert(plPropID);

    sqlite3_stmt *p = pCtx->pStmts[STMT_SEL_PROP_ID];
    assert(p);
    sqlite3_reset(p);
    sqlite3_bind_int64(p, 1, lClassID);
    sqlite3_bind_int64(p, 2, lPropNameID);
    int stepRes = sqlite3_step(p);
    if (stepRes != SQLITE_ROW)
        return stepRes;

    *plPropID = sqlite3_column_int64(p, 0);

    return SQLITE_OK;
}

/*
 * Ensures that there is given Name in [.names] table.
 * Returns name id in pNameID (if not null)
 */
int db_insert_name(struct flexi_db_context *pCtx, const char *zName, sqlite3_int64 *pNameID)
{
    assert(zName);
    {
        sqlite3_stmt *p = pCtx->pStmts[STMT_INS_NAME];
        assert(p);
        sqlite3_reset(p);
        sqlite3_bind_text(p, 1, zName, -1, NULL);
        int stepRes = sqlite3_step(p);
        if (stepRes != SQLITE_DONE)
            return stepRes;
    }

    int result = db_get_name_id(pCtx, zName, pNameID);

    return result;
}

void flexi_db_context_free(struct flexi_db_context *pCtx)
{
    // Release prepared SQL statements
    for (int ii = 0; ii <= STMT_DEL_FTS; ii++)
    {
        if (pCtx->pStmts[ii])
            sqlite3_finalize(pCtx->pStmts[ii]);
    }

    if (pCtx->pMatchFuncSelStmt != NULL)
    {
        sqlite3_finalize(pCtx->pMatchFuncSelStmt);
        pCtx->pMatchFuncSelStmt = NULL;
    }

    if (pCtx->pMatchFuncInsStmt != NULL)
    {
        sqlite3_finalize(pCtx->pMatchFuncInsStmt);
        pCtx->pMatchFuncInsStmt = NULL;
    }

    if (pCtx->pMemDB != NULL)
    {
        sqlite3_close(pCtx->pMemDB);
        pCtx->pMemDB = NULL;
    }

    flexi_free_user_info(pCtx->pCurrentUser);

    HashTable_clear(&pCtx->classDefs);

    /*
     *TODO Check 2nd param
     */
    if (pCtx->pDuk)
        duk_free(pCtx->pDuk, NULL);

    sqlite3_free(pCtx);
}

int db_get_class_id_by_name(struct flexi_db_context *pCtx,
                            const char *zClassName, sqlite3_int64 *pClassID)
{
    assert(pCtx);

    int result;
    if (!pCtx->pStmts[STMT_CLS_ID_BY_NAME])
    {
        CHECK_CALL(sqlite3_prepare_v2(pCtx->db,
                                      "select ClassID from [.classes] "
                                              "where NameID = (select ID from [.names_props] where Value = :1 limit 1);",
                                      -1, &pCtx->pStmts[STMT_CLS_ID_BY_NAME], NULL));
    }
    CHECK_CALL(sqlite3_reset(pCtx->pStmts[STMT_CLS_ID_BY_NAME]));
    CHECK_CALL(sqlite3_bind_text(pCtx->pStmts[STMT_CLS_ID_BY_NAME], 0, zClassName, -1, NULL));
    CHECK_STMT(sqlite3_step(pCtx->pStmts[STMT_CLS_ID_BY_NAME]));
    if (result == SQLITE_ROW)
    {
        *pClassID = sqlite3_column_int64(pCtx->pStmts[STMT_CLS_ID_BY_NAME], 0);
    }
    else
    { *pClassID = -1; }
    result = SQLITE_OK;

    goto CATCH;

    CATCH:

    FINALLY:
    return result;
}

/*
 * Initializes database connection wide SQL statements
 */
static int flexi_prepare_db_statements(struct flexi_db_context *pCtx)
{
    int result;
    sqlite3 *db = pCtx->db;
    const char *zDelObjSQL = "delete from [.objects] where ObjectID = :1;";
    CHECK_CALL(sqlite3_prepare_v2(db, zDelObjSQL, -1, &pCtx->pStmts[STMT_DEL_OBJ], NULL));

    const char *zInsObjSQL = "insert into [.objects] (ObjectID, ClassID, ctlo) values (:1, :2, :3); "
            "select last_insert_rowid();";
    CHECK_CALL(sqlite3_prepare_v2(db, zInsObjSQL, -1, &pCtx->pStmts[STMT_INS_OBJ], NULL));

    const char *zInsPropSQL = "insert into [.ref-values] (ObjectID, PropertyID, PropIndex, ctlv, [Value])"
            " values (:1, :2, :3, :4, :5);";
    CHECK_CALL(sqlite3_prepare_v2(db, zInsPropSQL, -1, &pCtx->pStmts[STMT_INS_PROP], NULL));

    const char *zUpdPropSQL = "insert or replace into [.ref-values] (ObjectID, PropertyID, PropIndex, ctlv, [Value])"
            " values (:1, :2, :3, :4, :5);";
    CHECK_CALL(sqlite3_prepare_v2(db, zUpdPropSQL, -1, &pCtx->pStmts[STMT_UPD_PROP], NULL));

    const char *zDelPropSQL = "delete from [.ref-values] where ObjectID = :1 and PropertyID = :2 and PropIndex = :3;";
    CHECK_CALL(sqlite3_prepare_v2(db, zDelPropSQL, -1, &pCtx->pStmts[STMT_DEL_PROP], NULL));

    const char *zInsNameSQL = "insert or replace into [.names] ([Value], NameID)"
            " values (:1, (select NameID from [.names] where Value = :1 limit 1));";
    CHECK_CALL(sqlite3_prepare_v2(db, zInsNameSQL, -1, &pCtx->pStmts[STMT_INS_NAME], NULL));

    CHECK_CALL(sqlite3_prepare_v2(
            db,
            "select ClassID from [.classes] where NameID = (select NameID from [.names] where [Value] = :1 limit 1);",
            -1, &pCtx->pStmts[STMT_SEL_CLS_BY_NAME], NULL));

    CHECK_CALL(sqlite3_prepare_v2(
            db,
            "select NameID from [.names] where [Value] = :1;",
            -1, &pCtx->pStmts[STMT_SEL_NAME_ID], NULL));

    CHECK_CALL(sqlite3_prepare_v2(
            db,
            "select PropertyID from [flexi_prop] where ClassID = :1 and NameID = :2;",
            -1, &pCtx->pStmts[STMT_SEL_PROP_ID], NULL));

    CHECK_CALL(sqlite3_prepare_v2(
            db,
            "insert into [.range_data] ([ObjectID], [ClassID], [ClassID_1], "
                    "[A0], [_1], [B0], [B1], [C0], [C1], [D0], [D1]) values "
                    "(:1, :2, :2, :3, :4, :5, :6, :7, :8, :9, :10);",
            -1, &pCtx->pStmts[STMT_INS_RTREE], NULL));

    CHECK_CALL(sqlite3_prepare_v2(
            db,
            "update [.range_data] set [ClassID] = :2, [ClassID_1] = :2, "
                    "[A0] = :3, [A1] = :4, [B0] = :5, [B1] = :6, "
                    "[C0] = :7, [C1] = :8, [D0] = :9, [D1] = :10 where ObjectID = :1;",
            -1, &pCtx->pStmts[STMT_UPD_RTREE], NULL));

    CHECK_CALL(sqlite3_prepare_v2(
            db, "delete from [.range_data] where ObjectID = :1;",
            -1, &pCtx->pStmts[STMT_DEL_RTREE], NULL));

    goto FINALLY;
    CATCH:
    FINALLY:
    return result;
}

static ReCompiled *pNameRegex = NULL;

static void NameRegex_free()
{
    re_free(pNameRegex);
}

bool db_validate_name(const unsigned char *zName)
{
    if (!zName)
        return false;

    const char *zNameRegex = "[_a-zA-Z][\-_a-zA-Z0-9]{1,128}";
    if (!pNameRegex)
    {
        re_compile(&pNameRegex, zNameRegex, 1);
        atexit(NameRegex_free);
    }
    int result = re_match(pNameRegex, zName, -1);
    return result != 0;
}