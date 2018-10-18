//
// Created by slanska on 2017-04-08.
//

#include "../project_defs.h"
#include "flexi_data.h"

SQLITE_EXTENSION_INIT3

#include "../misc/regexp.h"
//#include "flexi_class.h"

static int _disconnect(sqlite3_vtab *pVTab)
{
    // TODO
    return SQLITE_OK;
}

/*
** Set the pIdxInfo->estimatedRows variable to nRow. Unless this
** extension is currently being used by a version of SQLite too old to
** support estimatedRows. In that case this function is a no-op.
*/
static void setEstimatedRows(sqlite3_index_info *pIdxInfo, sqlite3_int64 nRow)
{
#if SQLITE_VERSION_NUMBER >= 3008002
    if (sqlite3_libversion_number() >= 3008002)
    {
        pIdxInfo->estimatedRows = nRow;
    }
#endif
}

/*
 * Finds best existing index for the given criteria, based on index definition for class' properties.
 * There are few search strategies. They fall into one of following groups:
 * I) search by rowid (ObjectID)
 * II) search by indexed properties
 * III) search by rtree ranges
 * IV) full text search (via match function)
 * Due to specifics of internal storage of data (EAV store), these strategies are estimated differently
 * For strategy II every additional search constraint increases estimated cost (since query in this case would be compound from multiple
 * joins)
 * For strategies III and IV it is opposite, every additional constraint reduces estimated cost, since lookup will need
 * to be performed on more restrictive criteria
 * Inside of each strategies there is also rank depending on op code (exact comparison gives less estimated cost, range comparison gives
 * more estimated cost)
 * Here is list of sorted from most efficient to least efficient strategies:
 * 1) lookup by object ID.
 * 2) exact value by indexed or unique column (=)
 * 3) lookup in rtree (by set of fields)
 * 4) range search on indexed or unique column (>, <, >=, <=, <>)
 * 5) full text search by text column indexed for FTS
 * 6) linear scan for exact value
 * 7) linear scan for range
 * 8) linear search for MATCH/REGEX/prefixed LIKE
 *
 *  # of scenario corresponds to idxNum value in output
 *  idxNum will have best found determines format of idxStr.
 *  1) idxStr is not used (null)
 *  2-8) idxStr consists of 6 char tuples with op & column index (+1) encoded
 *  into 2 and 4 hex characters respectively
 *  (e.g. "020003" means EQ operator for column #3). Position of every tuple
 *  corresponds to argvIndex, so that tupleIndex = (argvIndex - 1) * 6
 *   */
static int _best_index(
        sqlite3_vtab *tab,
        sqlite3_index_info *pIdxInfo
)
{
    int result = SQLITE_OK;

    int argCount = 0;

    pIdxInfo->idxStr = NULL;
    for (int jj = 0; jj < pIdxInfo->nConstraint; jj++)
    {
        if (pIdxInfo->aConstraint[jj].usable)
        {
            pIdxInfo->aConstraintUsage[jj].argvIndex = ++argCount;
            void *pTmp = pIdxInfo->idxStr;
            pIdxInfo->idxStr = sqlite3_mprintf("%s%2X|%4X|", pTmp, pIdxInfo->aConstraint[jj].op,
                                               pIdxInfo->aConstraint[jj].iColumn + 1);
            pIdxInfo->needToFreeIdxStr = 1;
            pIdxInfo->idxNum = 1; // TODO
            sqlite3_free(pTmp);
            pIdxInfo->estimatedCost = 0; // TODO
        }
    }

    return result;
}

/*
 * Delete class and all its object data
 */
static int _destroy(sqlite3_vtab *pVTab)
{
    //pVTab->pModule

    // TODO "delete from [.classes] where NameID = (select NameID from [.names] where Value = :name limit 1);"
    return SQLITE_OK;
}

/*
 * Starts SELECT on a Flexilite class
 */
static int _open(sqlite3_vtab *pVTab, sqlite3_vtab_cursor **ppCursor)
{
    int result;

    struct flexi_ClassDef_t *vtab = (struct flexi_ClassDef_t *) pVTab;
    // Cursor will have 2 prepared sqlite statements: 1) find object IDs by property values (either with index or not), 2) to iterate through found objects' properties
    struct flexi_VTabCursor *cur = NULL;
    CHECK_MALLOC(cur, sizeof(struct flexi_VTabCursor));

    *ppCursor = (void *) cur;
    memset(cur, 0, sizeof(*cur));

    cur->iEof = -1;
    cur->lObjectID = -1;

    const char *zPropSql = "select ObjectID, PropertyID, PropIndex, ctlv, [Value] from [.ref-values] "
            "where ObjectID = :1 order by ObjectID, PropertyID, PropIndex;";

    // TODO
    //    CHECK_STMT_PREPARE(vtab->pCtx->db, zPropSql, &cur->pPropertyIterator);

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:
    printf("%s", sqlite3_errmsg(vtab->pCtx->db));

    EXIT:
    return result;
}

/*
 * Cleans up column values left after last Next/Column calls.
 * Return 1 if cur->pCols is not null.
 * Otherwise, 0
 */
int flexi_free_cursor_values(struct flexi_VTabCursor *cur)
{
    if (cur->pCols != NULL)
    {
        struct flexi_ClassDef_t *vtab = (void *) cur->base.pVtab;
        for (int ii = 0; ii < vtab->propsByName.count; ii++)
        {
            if (cur->pCols[ii] != NULL)
            {
                sqlite3_value_free(cur->pCols[ii]);
                cur->pCols[ii] = NULL;
            }
        }

        return 1;
    }

    return 0;
}


int flexi_VTabCursor_free(struct flexi_VTabCursor *cur)
{
    flexi_free_cursor_values(cur);
    sqlite3_free(cur->pCols);

    sqlite3_finalize(cur->pObjectIterator);

    sqlite3_finalize(cur->pPropertyIterator);
    sqlite3_free(cur);
    return SQLITE_OK;
}

/*
 * Finishes SELECT
 */
static int _close(sqlite3_vtab_cursor *pCursor)
{
    struct flexi_VTabCursor *cur = (void *) pCursor;
    return flexi_VTabCursor_free(cur);

}

/*
 * Advances to the next found object
 */
static int _next(sqlite3_vtab_cursor *pCursor)
{
    int result;
    struct flexi_VTabCursor *cur = (void *) pCursor;
    struct flexi_ClassDef_t *vtab = (struct flexi_ClassDef_t *) cur->base.pVtab;

    cur->iReadCol = -1;
    result = sqlite3_step(cur->pObjectIterator);
    if (result == SQLITE_DONE)
    {
        cur->iEof = 1;
    }
    else
        if (result == SQLITE_ROW)
        {
            // Cleanup after last record
            if (flexi_free_cursor_values(cur) == 0)
            {
                CHECK_MALLOC(cur->pCols, vtab->propsByName.count * sizeof(sqlite3_value *));
            }
            memset(cur->pCols, 0, vtab->propsByName.count * sizeof(sqlite3_value *));

            cur->lObjectID = sqlite3_column_int64(cur->pObjectIterator, 0);
            cur->iEof = 0;
            CHECK_CALL(sqlite3_reset(cur->pPropertyIterator));
            sqlite3_bind_int64(cur->pPropertyIterator, 1, cur->lObjectID);
        }
        else goto ONERROR;

    result = SQLITE_OK;
    goto EXIT;
    ONERROR:
    {
        // Release resources because of errors (catch)
        printf("%s", sqlite3_errmsg(vtab->pCtx->db));
    }
    EXIT:
    return result;
}

/*
 * Generates dynamic SQL to find list of object IDs.
 * idxNum may be 0 or 1. When 1, idxStr will have all constraints appended by FindBestIndex.
 * Depending on number of constraint arguments in idxStr generated SQL will have of the following constructs:
 * 1. argc == 1 or all argv are for rtree search
 * 1.1. Unique index: select ObjectID from [.ref-values] where PropertyID = :1 and Value OP :2 and ctlv =
 * 1.2. Index: select ObjectID from [.ref-values] where PropertyID = :1 and Value OP :2 and ctlv =
 * 1.3. Match for full text search with index:
 * select id from [.full_text_data] where PropertyID = :1 and Value match :2
 * 1.4. Linear scan without index:
 * select ObjectID from [.ref-values] where PropertyID = :1 and Value OP :2
 * 1.5. Search by rtree:
 * select id from [.range_data] where ClassID = :1 and A0 OP :2 and A1 OP :3 and...
 *
 * 2.argc > 1
 * General pattern would be:
 * <SQL for argv == 0> intersect <SQL for argv == 1>...
 */
static int _filter(sqlite3_vtab_cursor *pCursor, int idxNum, const char *idxStr,
                   int argc, sqlite3_value **argv)
{
    static char *range_columns[] = {"A0", "A1", "B0", "B1", "C0", "C1", "D0", "D1"};

    int result;
    struct flexi_VTabCursor *cur = (void *) pCursor;
    struct flexi_ClassDef_t *vtab = (struct flexi_ClassDef_t *) cur->base.pVtab;
    char *zSQL = NULL;

    // Subquery for [.range_data]
    char *zRangeSQL = NULL;

    if (idxNum == 0 || argc == 0)
        // No special index used. Apply linear scan
    {
        CHECK_STMT_PREPARE(
                vtab->pCtx->db, "select ObjectID from [.objects] where ClassID = :1;",
                &cur->pObjectIterator);
        sqlite3_bind_int64(cur->pObjectIterator, 1, vtab->lClassID);
    }
    else
    {
        assert(argc * 8 == strlen(idxStr));

        const char *zIdxTuple = idxStr;
        for (int i = 0; i < argc; i++)
        {
            int op;
            int colIdx;
            sscanf(zIdxTuple, "%2X|%4X|", &op, &colIdx);
            colIdx--;
            zIdxTuple += 8;

            assert(colIdx >= -1 && colIdx < vtab->propsByName.count);

            if (zSQL != NULL)
            {
                void *pTmp = zSQL;
                zSQL = sqlite3_mprintf("%s intersect ", pTmp);
                sqlite3_free(pTmp);
            }

            char *zOp;
            switch (op)
            {
                case SQLITE_INDEX_CONSTRAINT_EQ:
                    zOp = "=";
                    break;
                case SQLITE_INDEX_CONSTRAINT_GT:
                    zOp = ">";
                    break;
                case SQLITE_INDEX_CONSTRAINT_LE:
                    zOp = "<=";
                    break;
                case SQLITE_INDEX_CONSTRAINT_LT:
                    zOp = "<";
                    break;
                case SQLITE_INDEX_CONSTRAINT_GE:
                    zOp = ">=";
                    break;
                default:
                    assert(op == SQLITE_INDEX_CONSTRAINT_MATCH);
                    zOp = "match";
                    break;
            }

            if (colIdx == -1)
                // Search by rowid / ObjectID
            {
                void *pTmp = zSQL;
                zSQL = sqlite3_mprintf(
                        "%s select ObjectID from [.objects] where ObjectID %s :%d",
                        pTmp, zOp, i + 1);
                sqlite3_free(pTmp);
            }
            else
            {
                struct flexi_PropDef_t *prop = &vtab->pProps[colIdx];
                if (IS_RANGE_PROPERTY(prop->type))
                    // Special case: range data request
                {
                    assert(prop->cRangeColumn > 0);

                    if (zRangeSQL == NULL)
                    {
                        zRangeSQL = sqlite3_mprintf(
                                "select id from [.range_data] where ClassID0 = %d and ClassID1 = %d ",
                                vtab->lClassID, vtab->lClassID);
                    }
                    void *pTmp = zRangeSQL;
                    zRangeSQL = sqlite3_mprintf("%s and %s %s :%d", pTmp, range_columns[prop->cRangeColumn - 1],
                                                zOp, i + 1);
                    sqlite3_free(pTmp);
                }
                else
                    // Normal column
                {
                    void *zTmp = zSQL;

                    if (op == SQLITE_INDEX_CONSTRAINT_MATCH && prop->bFullTextIndex)
                        // full text search
                    {
                        // TODO Generate lookup on [.full_text_data]
                    }
                    else
                    {
                        zSQL = sqlite3_mprintf
                                ("%sselect ObjectID from [.ref-values] where "
                                         "[PropertyID] = %d and [PropIndex] = 0 and ", zTmp,
                                 prop->iPropID);
                        sqlite3_free(zTmp);
                        if (op != SQLITE_INDEX_CONSTRAINT_MATCH)
                        {
                            zTmp = zSQL;
                            zSQL = sqlite3_mprintf("%s[Value] %s :%d", zTmp, zOp, i + 1);
                            sqlite3_free(zTmp);

                            if (prop->bIndexed)
                            {
                                void *pTmp = zSQL;
                                zSQL = sqlite3_mprintf("%s and (ctlv & %d) = %d", pTmp, CTLV_INDEX, CTLV_INDEX);
                                sqlite3_free(pTmp);
                            }
                            else
                                if (prop->bUnique)
                                {
                                    void *pTmp = zSQL;
                                    zSQL = sqlite3_mprintf("%s and (ctlv & %d) = %d", pTmp, CTLV_UNIQUE_INDEX,
                                                           CTLV_UNIQUE_INDEX);
                                    sqlite3_free(pTmp);
                                }
                        }
                        else
                        {
                            /*
                             * TODO
                             * mem database
                             *
                             */
                            zTmp = zSQL;
                            zSQL = sqlite3_mprintf("%smatch_text(:%d, [Value])", zTmp, i + 1);
                            sqlite3_free(zTmp);
                        }
                    }
                }
            }
        }

        if (zRangeSQL != NULL)
        {
            void *pTmp = zSQL;
            zSQL = sqlite3_mprintf("%s intersect %s", pTmp, zRangeSQL);
            sqlite3_free(pTmp);
        }

        CHECK_STMT_PREPARE(vtab->pCtx->db, zSQL, &cur->pObjectIterator);
        // Bind arguments
        for (int ii = 0; ii < argc; ii++)
        {
            sqlite3_bind_value(cur->pObjectIterator, ii + 1, argv[ii]);
        }
    }

    CHECK_CALL(_next(pCursor));

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    sqlite3_free(zSQL);
    sqlite3_free(zRangeSQL);

    return result;
}

/*
 * This is dummy MATCH function which always return 1 (i.e. found).
 * This function is needed as otherwise SQLite wouldn't allow to use MATCH call.
 * Actual implementation is done be FTS4 table (.full_text_data) - for FTS-indexed columns
 * or via linear FTS matching - for not-FTS-indexed columns
 */
static void matchDummyFunction(sqlite3_context *context, int argc, sqlite3_value **argv)
{
    sqlite3_result_int(context, 1);
}
//
// static void likeFunction(sqlite3_context *context, int argc, sqlite3_value **argv)
//{
//    // TODO Update lookup statistics
//    printf("like: %d", argc);
//    sqlite3_result_int(context, 1);
//}
//
//static void regexpFunction(sqlite3_context *context, int argc, sqlite3_value **argv)
//{
//    // TODO Update lookup statistics
//    printf("regexp: %d", argc);
//    sqlite3_result_int(context, 1);
//}

/*
 *
 */
static int _find_method(
        sqlite3_vtab *pVtab,
        int nArg,
        const char *zName,
        void (**pxFunc)(sqlite3_context *, int, sqlite3_value **),
        void **ppArg
)
{
    // match
    if (strcmp("match", zName) == 0)
    {
        *pxFunc = matchDummyFunction;
        return 1;
    }

    //    // like
    //    if (strcmp("like", zName) == 0)
    //    {
    //        *pxFunc = likeFunction;
    //        return 1;
    //    }
    //
    //    // glob
    //
    //    // regexp
    //    if (strcmp("regexp", zName) == 0)
    //    {
    //        *pxFunc = regexpFunction;
    //        return 1;
    //    }

    return 0;
}

/*
 * Returns 0 if EOF is not reached yet. 1 - if EOF (all rows processed)
 */
static int _eof(sqlite3_vtab_cursor *pCursor)
{
    struct flexi_VTabCursor *cur = (void *) pCursor;
    return cur->iEof > 0;
}

/*
 * Returns value for the column at position iCol (starting from 0).
 * Reads column data from ref-values table, filtered by ObjectID and sorted by PropertyID
 * For the sake of better performance, fetches required columns on demand, sequentially.
 *
 */
static int _column(sqlite3_vtab_cursor *pCursor, sqlite3_context *pContext, int iCol)
{
    int result = SQLITE_OK;
    struct flexi_VTabCursor *cur = (void *) pCursor;

    if (iCol == -1)
    {
        sqlite3_result_int64(pContext, cur->lObjectID);
        goto EXIT;
    }

    struct flexi_ClassDef_t *vtab = (void *) cur->base.pVtab;

    // First, check if column has been already loaded
    while (cur->iReadCol < iCol)
    {
        int colResult = sqlite3_step(cur->pPropertyIterator);
        if (colResult == SQLITE_DONE)
            break;
        if (colResult != SQLITE_ROW)
        {
            result = colResult;
            goto ONERROR;
        }
        sqlite3_int64 lPropID = sqlite3_column_int64(cur->pPropertyIterator, 1);
        if (lPropID < vtab->pProps[cur->iReadCol + 1].iPropID)
            continue;

        cur->iReadCol++;
        if (lPropID == vtab->pProps[cur->iReadCol].iPropID)
        {
            sqlite3_int64 lPropIdx = sqlite3_column_int64(cur->pPropertyIterator, 2);

            /*
             * No need in any special verification as we expect columns are sorted by property IDs, so
             * we just assume that once column index is OK, we can process this property data
             */

            cur->pCols[cur->iReadCol] = sqlite3_value_dup(sqlite3_column_value(cur->pPropertyIterator, 4));
        }
    }

    if (cur->pCols[iCol] == NULL || sqlite3_value_type(cur->pCols[iCol]) == SQLITE_NULL)
    {
        sqlite3_result_value(pContext, vtab->pProps[iCol].defaultValue);
    }
    else
    {
        sqlite3_result_value(pContext, cur->pCols[iCol]);
    }

    result = SQLITE_OK;
    goto EXIT;
    ONERROR:

    EXIT:
    // Map column number to property ID
    return result;
}

/*
 * Returns object ID into pRowID
 */
static int _row_id(sqlite3_vtab_cursor *pCursor, sqlite_int64 *pRowid)
{
    struct flexi_VTabCursor *cur = (void *) pCursor;
    *pRowid = cur->lObjectID;
    return SQLITE_OK;
}

/*
 * Validates data for the property by iCol index. Returns SQLITE_OK if validation was successful, or error code
 * otherwise
 */
static int flexi_validate_prop_data(struct flexi_ClassDef_t *pVTab, int iCol, sqlite3_value *v)
{
    // Assume error
    int result = SQLITE_ERROR;

    assert(iCol >= 0 && iCol < pVTab->propsByName.count);
    struct flexi_PropDef_t *pProp = &pVTab->pProps[iCol];

    result = flexi_PropDef_validateValue(pProp, pVTab, v);
    return result;
}

/*
 * Validates property values for the row to be inserted/updated
 * Returns SQLITE_OK if validation passed, or error code otherwise.
 * In case of error pVTab->base.zErrMsg will be set to the exact error message
 */
static int flexi_validate(struct flexi_ClassDef_t *pVTab, int argc, sqlite3_value **argv)
{
    int result = SQLITE_OK;

    for (int ii = 2; ii < argc; ii++)
    {
        CHECK_CALL(flexi_validate_prop_data(pVTab, ii - 2, argv[ii]));
    }

    goto EXIT;
    ONERROR:
    //
    EXIT:
    //
    return result;
}

/*
 * Saves property values for the given object ID
 */
static int flexi_upsert_props(struct flexi_ClassDef_t *pVTab, sqlite3_int64 lObjectID,
                              sqlite3_stmt *pStmt, int bDeleteNulls, int argc, sqlite3_value **argv)
{
    int result;

    sqlite3_stmt *pDelProp;

    CHECK_CALL(flexi_validate(pVTab, argc, argv));

    // Values are coming from index 2 (0 and 1 used for object IDs)
    for (int ii = 2; ii < argc; ii++)
    {
        struct flexi_PropDef_t *pProp = &pVTab->pProps[ii - 2];
        sqlite3_value *pVal = argv[ii];

        /*
         * Check if this is range property. If so, actual value can be specified either directly
         * in format 'LoValue|HiValue', or via following computed bound properties.
         * Base range property has priority, so if it is not NULL, it will be used as property value
        */
        int bIsNull = !(argv[ii] != NULL && sqlite3_value_type(argv[ii]) != SQLITE_NULL);
        if (IS_RANGE_PROPERTY(pProp->type))
        {
            assert(ii + 2 < argc);
            if (bIsNull)
            {
                if (argv[ii + 1] != NULL && sqlite3_value_type(argv[ii + 1]) != SQLITE_NULL
                    && argv[ii + 2] != NULL && sqlite3_value_type(argv[ii + 2]) != SQLITE_NULL)
                {
                    bIsNull = 0;
                }
            }
        }

        // Check if value is not null
        if (!bIsNull)
        {
            // TODO Check if this is a mapped column
            CHECK_CALL(sqlite3_reset(pStmt));
            sqlite3_bind_int64(pStmt, 1, lObjectID);
            sqlite3_bind_int64(pStmt, 2, pProp->iPropID);
            sqlite3_bind_int(pStmt, 3, 0);
            sqlite3_bind_int(pStmt, 4, pProp->xCtlv);

            if (!IS_RANGE_PROPERTY(pProp->type))
            {
                sqlite3_bind_value(pStmt, 5, pVal);
            }
            else
            {
                //                if (argv[ii] == NULL || sqlite3_value_type(argv[ii]) == SQLITE_NULL)
                //                {
                //                    char *zRange = NULL;
                //                    switch (pProp->type)
                //                    {
                //                        case PROP_TYPE_INTEGER_RANGE:
                //                            zRange = sqlite3_mprintf("%li|%li",
                //                                                     sqlite3_value_int64(argv[ii + 1]),
                //                                                     sqlite3_value_int64(argv[ii + 2]));
                //                            break;
                //
                //                        case PROP_TYPE_DECIMAL_RANGE:
                //                        {
                //                            double d0 = sqlite3_value_double(argv[ii + 1]);
                //                            double d1 = sqlite3_value_double(argv[ii + 2]);
                //                            long long i0 = (long long) (d0 * 10000);
                //                            long long i1 = (long long) (d1 * 10000);
                //                            zRange = sqlite3_mprintf("%li|%li", i0, i1);
                //                        }
                //
                //                            break;
                //
                //                        default:
                //                            zRange = sqlite3_mprintf("%f|%f",
                //                                                     sqlite3_value_double(argv[ii + 1]),
                //                                                     sqlite3_value_double(argv[ii + 2]));
                //                            break;
                //                    }
                //
                //                    sqlite3_bind_text(pStmt, 5, zRange, -1, NULL);
                //                    sqlite3_free(zRange);
                //                }
                //                else
                //                {
                //                    sqlite3_bind_value(pStmt, 5, pVal);
                //                }
                //                ii += 2;
            }

            CHECK_STMT_STEP(pStmt, pVTab->pCtx->db);
        }
        else
        {
            // Null value

            // TODO Check if this is a mapped column
            if (bDeleteNulls && pProp->cRngBound == 0)
            {
                const char *zDelPropSQL = "delete from [.ref-values] where ObjectID = :1 and PropertyID = :2 and PropIndex = :3;";
                CHECK_CALL(flexi_Context_stmtInit(pVTab->pCtx, STMT_DEL_PROP, zDelPropSQL, &pDelProp));
                sqlite3_bind_int64(pDelProp, 1, lObjectID);
                sqlite3_bind_int64(pDelProp, 2, pProp->iPropID);
                sqlite3_bind_int(pDelProp, 3, 0);
                CHECK_STMT_STEP(pDelProp, pVTab->pCtx->db);
            }
        }
    }

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    if (pVTab->base.zErrMsg == NULL)
    {
        // TODO Set message?
    }

    EXIT:
    return result;
}

/*
 * Performs INSERT, UPDATE and DELETE operations
 * argc == 1 -> DELETE, argv[0] - object ID or SQL_NULL
 * argv[1]: SQL_NULL ? allocate object ID and return it in pRowid : ID for new object
 *
 * argc = 1
The single row with rowid equal to argv[0] is deleted. No insert occurs.

argc > 1
argv[0] = NULL
A new row is inserted with a rowid argv[1] and column values in argv[2] and following.
 If argv[1] is an SQL NULL, the a new unique rowid is generated automatically.

argc > 1
argv[0] ≠ NULL
argv[0] = argv[1]
The row with rowid argv[0] is updated with new values in argv[2] and following parameters.

argc > 1
argv[0] ≠ NULL
argv[0] ≠ argv[1]
The row with rowid argv[0] is updated with rowid argv[1] and new values in argv[2] and following parameters.
 This will occur when an SQL statement updates a rowid, as in the statement:

UPDATE table SET rowid=rowid+1 WHERE ...;
 */
static int _update(sqlite3_vtab *pVTab, int argc, sqlite3_value **argv, sqlite_int64 *pRowid)
{
    int result = SQLITE_OK;
    struct flexi_ClassDef_t *vtab = (struct flexi_ClassDef_t *) pVTab;
    sqlite3_stmt *pDel;
    sqlite3_stmt *pDelRtree;
    sqlite3_stmt *pInsObj;
    sqlite3_stmt *pInsProp;
    sqlite3_stmt *pUpdProp;

    if (argc == 1)
        // Delete
    {
        if (sqlite3_value_type(argv[0]) == SQLITE_NULL)
            // Nothing to delete. Exit
        {
            return SQLITE_OK;
        }

        sqlite3_int64 lOldID = sqlite3_value_int64(argv[0]);

        CHECK_CALL(
                flexi_Context_stmtInit(vtab->pCtx, STMT_DEL_OBJ, "delete from [.objects] where ObjectID = :1;", &pDel));
        sqlite3_bind_int64(pDel, 1, lOldID);
        CHECK_STMT_STEP(pDel, vtab->pCtx->db);

        // TODO Move rtree delete init here
        pDelRtree = vtab->pCtx->pStmts[STMT_DEL_RTREE];
        assert(pDelRtree);
        CHECK_CALL(sqlite3_reset(pDelRtree));
        sqlite3_bind_int64(pDelRtree, 1, lOldID);
        CHECK_STMT_STEP(pDelRtree, vtab->pCtx->db);
    }
    else
    {
        if (sqlite3_value_type(argv[0]) == SQLITE_NULL)
            // Insert new row
        {
            const char *zInsObjSQL = "insert into [.objects] (ObjectID, ClassID, ctlo) values (:1, :2, :3); "
                    "select last_insert_rowid();";
            flexi_Context_stmtInit(vtab->pCtx, STMT_INS_OBJ, zInsObjSQL, &pInsObj);

            sqlite3_bind_value(pInsObj, 1, argv[1]); // Object ID, normally null
            sqlite3_bind_int64(pInsObj, 2, vtab->lClassID);
            sqlite3_bind_int(pInsObj, 3, vtab->xCtloMask);

            CHECK_STMT_STEP(pInsObj, vtab->pCtx->db);

            if (sqlite3_value_type(argv[1]) == SQLITE_NULL)
            {
                *pRowid = sqlite3_last_insert_rowid(vtab->pCtx->db);
            }
            else *pRowid = sqlite3_value_int64(argv[1]);

            const char *zInsPropSQL = "insert into [.ref-values] (ObjectID, PropertyID, PropIndex, ctlv, [Value])"
                    " values (:1, :2, :3, :4, :5);";
            CHECK_CALL(flexi_Context_stmtInit(vtab->pCtx, STMT_INS_PROP, zInsPropSQL, &pInsProp));
            CHECK_CALL(flexi_upsert_props(vtab, *pRowid, pInsProp, 0, argc, argv));
        }
        else
        {
            sqlite3_int64 lNewID = sqlite3_value_int64(argv[1]);
            *pRowid = lNewID;
            if (argv[0] != argv[1])
                // Special case - Object ID update
            {
                sqlite3_int64 lOldID = sqlite3_value_int64(argv[0]);

                // TODO Move stmt init here
                sqlite3_stmt *pUpdObjID = vtab->pCtx->pStmts[STMT_UPD_OBJ_ID];
                CHECK_CALL(sqlite3_reset(pUpdObjID));
                sqlite3_bind_int64(pUpdObjID, 1, lNewID);
                sqlite3_bind_int64(pUpdObjID, 2, vtab->lClassID);
                sqlite3_bind_int64(pUpdObjID, 3, lOldID);
                CHECK_STMT_STEP(pUpdObjID, vtab->pCtx->db);
            }

            const char *zUpdPropSQL = "insert or replace into [.ref-values] (ObjectID, PropertyID, PropIndex, ctlv, [Value])"
                    " values (:1, :2, :3, :4, :5);";
            flexi_Context_stmtInit(vtab->pCtx, STMT_UPD_PROP, zUpdPropSQL, &pUpdProp);
            CHECK_CALL(flexi_upsert_props(vtab, *pRowid, pUpdProp, 1, argc, argv));
        }
    }

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:
    printf("%s", sqlite3_errmsg(vtab->pCtx->db));

    EXIT:

    return result;
}

/*
 * Renames class to a new name (zNew)
 * TODO use flexi_class_rename
 */
static int _rename(sqlite3_vtab *pVtab, const char *zNew)
{
    struct flexi_ClassDef_t *pTab = (void *) pVtab;
    assert(pTab->lClassID != 0);

    return flexi_class_rename(pTab->pCtx, pTab->lClassID, zNew);
}

/*
*
Class definition
proxy module
.
* Used for
virtual table
create and
connect
*/

/*
 *   int iVersion;
  int (*xCreate)(sqlite3*, void *pAux,
               int argc, const char *const*argv,
               sqlite3_vtab **ppVTab, char**);
  int (*xConnect)(sqlite3*, void *pAux,
               int argc, const char *const*argv,
               sqlite3_vtab **ppVTab, char**);
  int (*xBestIndex)(sqlite3_vtab *pVTab, sqlite3_index_info*);
  int (*xDisconnect)(sqlite3_vtab *pVTab);
  int (*xDestroy)(sqlite3_vtab *pVTab);
  int (*xOpen)(sqlite3_vtab *pVTab, sqlite3_vtab_cursor **ppCursor);
  int (*xClose)(sqlite3_vtab_cursor*);
  int (*xFilter)(sqlite3_vtab_cursor*, int idxNum, const char *idxStr,
                int argc, sqlite3_value **argv);
  int (*xNext)(sqlite3_vtab_cursor*);
  int (*xEof)(sqlite3_vtab_cursor*);
  int (*xColumn)(sqlite3_vtab_cursor*, sqlite3_context*, int);
  int (*xRowid)(sqlite3_vtab_cursor*, sqlite3_int64 *pRowid);
  int (*xUpdate)(sqlite3_vtab *, int, sqlite3_value **, sqlite3_int64 *);
  int (*xBegin)(sqlite3_vtab *pVTab);
  int (*xSync)(sqlite3_vtab *pVTab);
  int (*xCommit)(sqlite3_vtab *pVTab);
  int (*xRollback)(sqlite3_vtab *pVTab);
  int (*xFindFunction)(sqlite3_vtab *pVtab, int nArg, const char *zName,
                       void (**pxFunc)(sqlite3_context*,int,sqlite3_value**),
                       void **ppArg);
  int (*xRename)(sqlite3_vtab *pVtab, const char *zNew);
   The methods above are in version 1 of the sqlite_module object. Those
  ** below are for version 2 and greater.
int (*xSavepoint)(sqlite3_vtab *pVTab, int);

int (*xRelease)(sqlite3_vtab *pVTab, int);

int (*xRollbackTo)(sqlite3_vtab *pVTab, int);

*/
sqlite3_module _classDefProxyModule = {
        .iVersion = 0,
        .xCreate = NULL,
        .xConnect = NULL,
        .xBestIndex = _best_index,
        .xDisconnect = _disconnect,
        .xDestroy = _destroy,
        .xOpen = _open,
        .xClose = _close,
        .xFilter = _filter,
        .xNext = _next,
        .xEof = _eof,
        .xColumn = _column,
        .xRowid = _row_id,
        .xUpdate = _update,
        .xBegin = NULL,
        .xSync = NULL,
        .xCommit= NULL,
        .xRollback = NULL,
        .xFindFunction = _find_method,
        .xRename = _rename,
        .xSavepoint = NULL,
        .xRelease = NULL
};
