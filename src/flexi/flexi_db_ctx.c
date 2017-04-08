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
//static int flexi_prepare_db_statements(struct flexi_Context_t *pCtx);

struct flexi_Context_t *flexi_Context_new(sqlite3 *db)
{
    struct flexi_Context_t *result = sqlite3_malloc(sizeof(struct flexi_Context_t));
    if (!result)
        return NULL;
    memset(result, 0, sizeof(struct flexi_Context_t));
    result->db = db;
    HashTable_init(&result->classDefsByName, DICT_STRING, (void *) flexi_ClassDef_free);
    HashTable_init(&result->classDefsById, DICT_INT, NULL);
    return result;
}

/*
 * Gets name ID by value. Name is expected to exist
 */
int flexi_Context_getNameId(struct flexi_Context_t *pCtx,
                            const char *zName, sqlite3_int64 *pNameID)
{
    int result;
    if (pNameID)
    {
        if (pCtx->pStmts[STMT_SEL_NAME_ID] == NULL)
        {
            CHECK_STMT_PREPARE(
                    pCtx->db,
                    "select NameID from [.names] where [Value] = :1;",
                    &pCtx->pStmts[STMT_SEL_NAME_ID]);
        }

        sqlite3_stmt *p = pCtx->pStmts[STMT_SEL_NAME_ID];

        sqlite3_reset(p);
        sqlite3_bind_text(p, 1, zName, -1, NULL);
        int stepRes = sqlite3_step(p);
        if (stepRes != SQLITE_ROW)
            return stepRes;

        *pNameID = sqlite3_column_int64(p, 0);
    }

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;
}

/*
 * Finds property ID by its class ID and name ID
 */
int flexi_Context_getPropIdByClassAndNameIds
        (struct flexi_Context_t *pCtx,
         sqlite3_int64 lClassID, sqlite3_int64 lPropNameID, sqlite3_int64 *plPropID)
{
    assert(plPropID);

    int result;

    if (pCtx->pStmts[STMT_SEL_PROP_ID] == NULL)
    {
        CHECK_STMT_PREPARE(
                pCtx->db,
                "select PropertyID from [flexi_prop] where ClassID = :1 and NameID = :2;",
                &pCtx->pStmts[STMT_SEL_PROP_ID]);
    }

    sqlite3_stmt *p = pCtx->pStmts[STMT_SEL_PROP_ID];
    assert(p);
    sqlite3_reset(p);
    sqlite3_bind_int64(p, 1, lClassID);
    sqlite3_bind_int64(p, 2, lPropNameID);
    int stepRes = sqlite3_step(p);
    if (stepRes != SQLITE_ROW)
        return stepRes;

    *plPropID = sqlite3_column_int64(p, 0);

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;
}

/*
 * Ensures that there is given Name in [.names] table.
 * Returns name id in pNameID (if not null)
 */
int flexi_Context_insertName(struct flexi_Context_t *pCtx, const char *zName, sqlite3_int64 *pNameID)
{
    int result;
    assert(zName);
    {
        if (pCtx->pStmts[STMT_INS_NAME] == NULL)
        {
            const char *zInsNameSQL = "insert or replace into [.names] ([Value], NameID)"
                    " values (:1, (select ID from [.names_props] where Value = :1 limit 1));";
            CHECK_STMT_PREPARE(pCtx->db, zInsNameSQL, &pCtx->pStmts[STMT_INS_NAME]);
        }

        sqlite3_stmt *p = pCtx->pStmts[STMT_INS_NAME];
        sqlite3_reset(p);
        sqlite3_bind_text(p, 1, zName, -1, NULL);
        int stepRes = sqlite3_step(p);
        if (stepRes != SQLITE_DONE)
            return stepRes;
    }

    CHECK_CALL(flexi_Context_getNameId(pCtx, zName, pNameID));
    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;
}

void flexi_Context_free(struct flexi_Context_t *pCtx)
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

    flexi_UserInfo_free(pCtx->pCurrentUser);

    HashTable_clear(&pCtx->classDefsByName);
    HashTable_clear(&pCtx->classDefsById);

    /*
     *TODO Check 2nd param
     */
    if (pCtx->pDuk)
        duk_free(pCtx->pDuk, NULL);

    sqlite3_free(pCtx);
}

int flexi_Context_getClassIdByName(struct flexi_Context_t *pCtx,
                                   const char *zClassName, sqlite3_int64 *pClassID)
{
    assert(pCtx);

    int result;
    if (!pCtx->pStmts[STMT_CLS_ID_BY_NAME])
    {
        CHECK_STMT_PREPARE(pCtx->db,
                           "select ClassID from [.classes] "
                                   "where NameID = (select ID from [.names_props] where Value = :1 limit 1);",
                           &pCtx->pStmts[STMT_CLS_ID_BY_NAME]);
    }
    CHECK_CALL(sqlite3_reset(pCtx->pStmts[STMT_CLS_ID_BY_NAME]));
    CHECK_CALL(sqlite3_bind_text(pCtx->pStmts[STMT_CLS_ID_BY_NAME], 1, zClassName, -1, NULL));
    CHECK_STMT_STEP(pCtx->pStmts[STMT_CLS_ID_BY_NAME]);
    if (result == SQLITE_ROW)
    {
        *pClassID = sqlite3_column_int64(pCtx->pStmts[STMT_CLS_ID_BY_NAME], 0);
    }
    else
    { *pClassID = -1; }
    result = SQLITE_OK;

    goto EXIT;

    ONERROR:

    EXIT:
    return result;
}

/*
 * Initializes database connection wide SQL statements
 */
static int flexi_prepare_db_statements(struct flexi_Context_t *pCtx)
{
    int result;
    sqlite3 *db = pCtx->db;

    // TODO move to RTRee related code
    CHECK_STMT_PREPARE(
            db,
            "insert into [.range_data] ([ObjectID], [ClassID], [ClassID_1], "
                    "[A0], [_1], [B0], [B1], [C0], [C1], [D0], [D1]) values "
                    "(:1, :2, :2, :3, :4, :5, :6, :7, :8, :9, :10);",
            &pCtx->pStmts[STMT_INS_RTREE]);

    CHECK_STMT_PREPARE(
            db,
            "update [.range_data] set [ClassID] = :2, [ClassID_1] = :2, "
                    "[A0] = :3, [A1] = :4, [B0] = :5, [B1] = :6, "
                    "[C0] = :7, [C1] = :8, [D0] = :9, [D1] = :10 where ObjectID = :1;",
            &pCtx->pStmts[STMT_UPD_RTREE]);

    CHECK_STMT_PREPARE(
            db, "delete from [.range_data] where ObjectID = :1;",
            &pCtx->pStmts[STMT_DEL_RTREE]);

    goto EXIT;
    ONERROR:

    EXIT:
    return result;
}

static ReCompiled *pNameRegex = NULL;

static void NameRegex_free()
{
    re_free(pNameRegex);
}

bool db_validate_name(const char *zName)
{
    if (!zName)
        return false;

    const char *zNameRegex = "[_a-zA-Z][\\-_a-zA-Z0-9]{1,128}";
    if (!pNameRegex)
    {
        re_compile(&pNameRegex, zNameRegex, 1);
        atexit(NameRegex_free);
    }
    int result = re_match(pNameRegex, (const unsigned char *) zName, -1);
    return result != 0;
}

int flexi_Context_addClassDef(struct flexi_Context_t *self, flexi_ClassDef_t *pClassDef)
{
    int result;

    HashTable_set(&self->classDefsByName, (DictionaryKey_t) {.pKey =  pClassDef->name.name}, pClassDef);
    HashTable_set(&self->classDefsById, (DictionaryKey_t) {.iKey =  pClassDef->lClassID}, pClassDef);
    pClassDef->nRefCount++;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:

    return result;
}

int flexi_Context_getClassByName(struct flexi_Context_t *self, const char *zClassName, flexi_ClassDef_t **ppClassDef)
{
    *ppClassDef = HashTable_get(&self->classDefsByName, (DictionaryKey_t) {.pKey = zClassName});
    return *ppClassDef != NULL;
}

int flexi_Context_getClassById(struct flexi_Context_t *self, sqlite3_int64 lClassId, flexi_ClassDef_t **ppClassDef)
{
    *ppClassDef = HashTable_get(&self->classDefsByName, (DictionaryKey_t) {.iKey = lClassId});
    return *ppClassDef != NULL;
}

int getColumnAsText(char **pzDest, sqlite3_stmt *pStmt, int iCol)
{
    *pzDest = NULL;
    char *zSrc = (char *) sqlite3_column_text(pStmt, iCol);
    if (zSrc == NULL)
        return SQLITE_OK;
    size_t len = strlen(zSrc);
    if (len == 0)
        return SQLITE_OK;

    *pzDest = sqlite3_malloc((int)len + 1);
    if (*pzDest == NULL)
        return SQLITE_NOMEM;
    strncpy(*pzDest, (char *) sqlite3_column_text(pStmt, iCol), len);
    (*pzDest)[len] = 0;

    return SQLITE_OK;
}
