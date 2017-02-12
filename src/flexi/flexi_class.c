//
// Created by slanska on 2017-02-08.
//

/*
 * flexi_class implementation of Flexilite class API
 */

#include "../project_defs.h"

///
/// \param context
/// \param zClassName
/// \param zClassDef
/// \param bCreateVTable
/// \param pzError
/// \return
int flexi_class_create(sqlite3 *db,
        // User data
                       void *pAux,
                       const char *zClassName,
                       const char *zClassDef,
                       int bCreateVTable,
                       char **pzError) {
    int result = SQLITE_OK;

    // Disposable resources
    sqlite3_stmt *pExtractProps = NULL;
    sqlite3_stmt *pInsClsStmt = NULL;
    sqlite3_stmt *pInsPropStmt = NULL;
    sqlite3_stmt *pUpdClsStmt = NULL;
    unsigned char *zPropDefJSON = NULL;
    char *sbClassDefJSON = sqlite3_mprintf("{\"properties\":{");

    struct flexi_db_env *pDBEnv = pAux;

    struct flexi_prop_metadata dProp;
    memset(&dProp, 0, sizeof(dProp));

    sqlite3_int64 lClassNameID;
    CHECK_CALL(db_insert_name(pDBEnv, zClassName, &lClassNameID));

    // insert into .classes
    {
        const char *zInsClsSQL = "insert into [.classes] (NameID) values (:1);";

        CHECK_CALL(sqlite3_prepare_v2(db, zInsClsSQL, -1, &pInsClsStmt, NULL));
        sqlite3_bind_int64(pInsClsStmt, 1, lClassNameID);
        int stepResult = sqlite3_step(pInsClsStmt);
        if (stepResult != SQLITE_DONE) {
            result = stepResult;
            goto CATCH;
        }
    }

    sqlite3_int64 iClassID;
    {
        sqlite3_stmt *p = pDBEnv->pStmts[STMT_SEL_CLS_BY_NAME];
        assert(p);
        sqlite3_reset(p);
        sqlite3_bind_text(p, 1, zClassName, -1, NULL);
        int stepRes = sqlite3_step(p);
        if (stepRes != SQLITE_ROW) {
            result = stepRes;
            goto CATCH;
        }

        iClassID = sqlite3_column_int64(p, 0);
    }

    int xCtloMask = 0;

    const char *zInsPropSQL = "insert into [.class_properties] (NameID, ClassID, ctlv, ctlvPlan)"
            " values (:1, :2, :3, :4);";
    CHECK_CALL(sqlite3_prepare_v2(db, zInsPropSQL, -1, &pInsPropStmt, NULL));

    // We expect 1st argument passed (at argv[3]) to be valid JSON which describes class
    // (should follow IClassDefinition specification)

    const char *zExtractPropSQL = "select "
            "coalesce(json_extract(value, '$.indexed'), 0) as indexed," // 0
            "coalesce(json_extract(value, '$.unique'), 0) as [unique]," // 1
            "coalesce(json_extract(value, '$.fastTextSearch'), 0) as fastTextSearch," // 2
            "coalesce(json_extract(value, '$.role'), 0) as role," // 3
            "coalesce(json_extract(value, '$.rules.type'), 0) as type," // 4
            "key as prop_name," // 5
            "value as prop_def" // 6 - Original property definition JSON
            " from json_each(:1, '$.properties');";

    // Need to remove leading and trailing quotes
    int iJSONLen = (int) strlen(zClassDef);
    CHECK_CALL(sqlite3_prepare_v2(db, zExtractPropSQL, -1, &pExtractProps, NULL));
    CHECK_CALL(sqlite3_bind_text(pExtractProps, 1, zClassDef + sizeof(char), iJSONLen - 2, NULL));

    int iPropCnt = 0;

    // Load property definitions from JSON
    while (1) {
        int iStep = sqlite3_step(pExtractProps);
        if (iStep == SQLITE_DONE)
            break;

        if (iStep != SQLITE_ROW) {
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
        sqlite3_free(dProp.zName);
        dProp.zName = sqlite3_malloc(sqlite3_column_bytes(pExtractProps, 5) + 1);
        zPropDefJSON = sqlite3_malloc(sqlite3_column_bytes(pExtractProps, 6) + 1);
        strcpy(dProp.zName, (const char *) sqlite3_column_text(pExtractProps, 5));
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

        switch (dProp.type) {
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
                if (dProp.bUnique || (dProp.xRole & PROP_ROLE_ID) || (dProp.xRole & PROP_ROLE_NAME)) {
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
        CHECK_CALL(db_insert_name(pDBEnv, dProp.zName, &lPropNameID));

        {
            sqlite3_reset(pInsPropStmt);
            sqlite3_bind_int64(pInsPropStmt, 1, lPropNameID);
            sqlite3_bind_int64(pInsPropStmt, 2, iClassID);
            sqlite3_bind_int(pInsPropStmt, 3, xCtlv);
            sqlite3_bind_int(pInsPropStmt, 4, xCtlvPlan);
            int stepResult = sqlite3_step(pInsPropStmt);
            if (stepResult != SQLITE_DONE) {
                result = stepResult;
                goto CATCH;
            }
        }

        // Get new property ID
        sqlite3_int64 iPropID;
        CHECK_CALL(db_get_prop_id_by_class_and_name(pDBEnv, iClassID, lPropNameID, &iPropID));
        if (iPropCnt != 0) {
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
    CHECK_CALL(sqlite3_prepare_v2(db, zUpdClsSQL, -1, &pUpdClsStmt, NULL));
    sqlite3_bind_text(pUpdClsStmt, 1, sbClassDefJSON, (int) strlen(sbClassDefJSON), NULL);
    sqlite3_bind_int(pUpdClsStmt, 2, xCtloMask);
    sqlite3_bind_int64(pUpdClsStmt, 3, iClassID);
    int updResult = sqlite3_step(pUpdClsStmt);
    if (updResult != SQLITE_DONE) {
        result = updResult;
        goto CATCH;
    }

    // TODO
//    CHECK_CALL(flexi_load_class_def(db, pAux, zClassName, ppVTab, pzErr));

    result = SQLITE_OK;

    goto FINALLY;

    CATCH:
    // Release resources because of errors (catch)
    printf("%s", sqlite3_errmsg(db));

    FINALLY:

    sqlite3_free((void *) zPropDefJSON);
    sqlite3_free(dProp.zName);

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

/// Creates Flexilite class
/// \param context
/// \param argc
/// \param argv
static void flexi_class_create_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
) {
    assert(argc == 2 || argc == 3);

    // 1st arg: class name
    const char *zClassName = (const char *) sqlite3_value_text(argv[0]);

    // 2nd arg: class definition, in JSON format
    const char *zClassDef = (const char *) sqlite3_value_text(argv[1]);

    // 3rd arg (optional): create virtual table
    int bCreateVTable = 0;
    if (argc == 3)
        bCreateVTable = sqlite3_value_int(argv[2]);

    char *zError = NULL;

    sqlite3 *db = sqlite3_context_db_handle(context);

    int result = SQLITE_OK;
    char *zSQL = NULL;
    if (bCreateVTable) {
        zSQL = sqlite3_mprintf("create virtual table using 'flexi' [%s] ('%s')", zClassName, zClassDef);
        CHECK_CALL(sqlite3_exec(db, zSQL, NULL, NULL, &zError));
    } else {
        void *pAux = sqlite3_user_data(context);
        CHECK_CALL(flexi_class_create(db, pAux, zClassName, zClassDef, bCreateVTable, &zError));
    }

    goto FINALLY;

    CATCH:
    if (zError) {
        sqlite3_result_error(context, zError, result);
        sqlite3_free(zError);
    }

    FINALLY:
    sqlite3_free(zSQL);
}

///
/// \param context
/// \param argc
/// \param argv
static void flexi_class_alter_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
) {
    assert(argc == 2);
    // 1st arg: class name
    char *zClassName = (char *) sqlite3_value_text(argv[0]);

    // 2nd arg: new class definition
    char *zNewClassDef = (char *) sqlite3_value_text(argv[1]);

}

///
/// \param context
/// \param argc
/// \param argv
static void flexi_class_drop_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
) {
    assert(argc == 2 || argc == 1);
    // 1st arg: class name
    char *zClassName = (char *) sqlite3_value_text(argv[0]);

    // 2nd (optional): soft delete flag (if true, existing data will be preserved)
    int softDel = 0;
    if (argc == 2)
        softDel = sqlite3_value_int(argv[1]);

}

///
/// \param context
/// \param argc
/// \param argv
static void flexi_class_rename_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
) {
    assert(argc == 2);
    // 1st arg: existing class name
    char *zOldClassName = (char *) sqlite3_value_text(argv[0]);

    // 2nd arg: new class name
    char *zNewClassName = (char *) sqlite3_value_text(argv[1]);
}

int flexi_class_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi) {
    int result = SQLITE_OK;
    CHECK_CALL(sqlite3_create_function_v2(db, "flexi_class_create",
                                          2, SQLITE_UTF8, NULL,
                                          flexi_class_create_func,
                                          0, 0, NULL));
    CHECK_CALL(sqlite3_create_function_v2(db, "flexi_class_create",
                                          3, SQLITE_UTF8, NULL,
                                          flexi_class_create_func,
                                          0, 0, NULL));
    CHECK_CALL(sqlite3_create_function_v2(db, "flexi_class_alter", 2,
                                          SQLITE_UTF8, NULL,
                                          flexi_class_alter_func, 0, 0, 0));
    CHECK_CALL(sqlite3_create_function_v2(db, "flexi_class_drop", 1,
                                          SQLITE_UTF8, NULL,
                                          flexi_class_alter_func, 0, 0, 0));
    CHECK_CALL(sqlite3_create_function_v2(db, "flexi_class_rename", 2,
                                          SQLITE_UTF8, NULL,
                                          flexi_class_alter_func, 0, 0, 0));
    goto FINALLY;

    CATCH:
    FINALLY:
    return result;
}



