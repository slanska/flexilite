//
// Created by slanska on 2017-02-16.
//

#include <stddef.h>
#include "flexi_db_ctx.h"
#include "flexi_class.h"

struct flexi_db_context *flexi_db_context_new(sqlite3 *db)
{
    struct flexi_db_context *result = sqlite3_malloc(sizeof(struct flexi_db_context));
    if (!result)
        return NULL;
    memset(result, 0, sizeof(struct flexi_db_context));
    result->db = db;
    HashTable_init(&result->classDefs, (void *) flexi_class_def_free);
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

/*
 * Cleans up Flexilite module environment (prepared SQL statements etc.)
 */
void flexi_db_context_deinit(struct flexi_db_context *pCtx)
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

    memset(pCtx, 0, sizeof(*pCtx));
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

