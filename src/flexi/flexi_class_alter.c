//
// Created by slanska on 2016-04-23.
//

/*
 * Implementation of class alteration
 */

#include "../project_defs.h"
#include "flexi_class.h"

static int _merge_class_schemas(struct flexi_db_context *pCtx,
                                sqlite3_int64 lClassID, const char *zNewClassDef,
                                const char **pzMergedSchema,
                                const char **pzError)
{
    int result;

    return result;
}

static int _createClassDefFromDefJSON(struct flexi_db_context *pCtx, const char *zClassDefJson,
                                      struct flexi_class_def **pClassDef)
{
    int result;
    const char *zErr = NULL;

    *pClassDef = flexi_class_def_new(pCtx);
    if (!*pClassDef)
    {
        result = SQLITE_NOMEM;
        goto CATCH;
    }

    CHECK_CALL(flexi_class_def_parse(*pClassDef, zClassDefJson, &zErr));

    result = SQLITE_OK;
    goto FINALLY;

    CATCH:

    FINALLY:
    return result;
}

static int _alter_class_with_data(struct flexi_db_context *pCtx,
                                  sqlite3_int64 lClassID, const char *zNewClassDef,
                                  const char **pzError)
{
    int result;

    // load existing schema


    // Check if there are changes in full text data, range data, indexes, reference and enum properties

    // Merge existing and new definitions

    // Validate new schema

    // Detect if we 'shrink' schema. Means that existing data validation and transformation may be needed

    // If schema is not 'shrink', simply apply new schema

    goto FINALLY;

    CATCH:

    FINALLY:
    return result;
}

/*
 * Generic function to alter class definition
 * Performs all validations and necessary data updates
 */
int flexi_class_alter(struct flexi_db_context *pCtx,
                      const char *zClassName,
                      const char *zNewClassDefJson,
                      int bCreateVTable,
                      const char **pzError
)
{
    int result;

    // Check if class exists. If no - error
    // Check if class does not exist yet
    sqlite3_int64 lClassID;
    CHECK_CALL(db_get_class_id_by_name(pCtx, zClassName, &lClassID));
    if (lClassID <= 0)
    {
        result = SQLITE_ERROR;
        *pzError = sqlite3_mprintf("Class [%s] is not found", zClassName);
        goto CATCH;
    }

    // Check if class has any objects created. If no - treat as create
    if (!pCtx->pStmts[STMT_CLS_HAS_DATA])
    {
        CHECK_CALL(sqlite3_prepare_v2(pCtx->db,
                                      "select 1 from [.objects] where ClassID = :1 and ObjectID > 0 limit 1;",
                                      -1, &pCtx->pStmts[STMT_CLS_HAS_DATA], NULL));
    }
    CHECK_CALL(sqlite3_reset(pCtx->pStmts[STMT_CLS_HAS_DATA]));
    CHECK_CALL(sqlite3_bind_int64(pCtx->pStmts[STMT_CLS_HAS_DATA], 0, lClassID));
    CHECK_STMT(sqlite3_step(pCtx->pStmts[STMT_CLS_HAS_DATA]));
    if (result == SQLITE_DONE)
    {
        CHECK_CALL(flexi_alter_new_class(pCtx, lClassID, zNewClassDefJson, pzError));
    }
    else
    {
        CHECK_CALL(_alter_class_with_data(pCtx, lClassID, zNewClassDefJson, pzError));
    }

    goto FINALLY;

    CATCH:
    if (!*pzError)
        *pzError = sqlite3_errstr(result);

    FINALLY:
    return result;
}

/*
 *
 */
int flexi_alter_new_class(struct flexi_db_context *pCtx, sqlite3_int64 lClassID,
                          const char *zNewClassDef, const char **pzErr)
{
    int result;

    assert(pCtx && pCtx->db);

    result = SQLITE_OK;
    struct flexi_class_def *pNewClassDef = NULL;

    // Load existing class def
    struct flexi_class_def *pClassDef = NULL;
    CHECK_CALL(flexi_class_def_load(pCtx, lClassID, &pClassDef, pzErr));

    // Parse new definition
    CHECK_CALL(_createClassDefFromDefJSON(pCtx, zNewClassDef, &pNewClassDef));
    pNewClassDef->lClassID = lClassID;

    // Validate definition

    // Merge existing definition with new one.
    //    _merge_class_schemas(pCtx,)



    goto FINALLY;

    CATCH:
    if (pClassDef)
        flexi_class_def_free(pClassDef);

    FINALLY:

    return result;
}


