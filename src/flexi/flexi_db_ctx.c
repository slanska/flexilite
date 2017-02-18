//
// Created by slanska on 2017-02-16.
//

#include <stddef.h>
#include "flexi_db_ctx.h"
#include "../misc/regexp.h"
#include "../project_defs.h"

/*
 *
 */
static void flexi_vtab_prop_free(struct flexi_prop_metadata const *prop) {
    sqlite3_value_free(prop->defaultValue);
    sqlite3_free(prop->zName);
    sqlite3_free(prop->regex);
    if (prop->pRegexCompiled)
        re_free(prop->pRegexCompiled);
}

void flexi_free_user_info(struct flexi_user_info *p) {
    if (p) {
        sqlite3_free(p->zUserID);
        for (int ii = 0; ii < p->nRoles; ii++) {
            sqlite3_free(p->zRoles[ii]);
        }
        sqlite3_free(p->zRoles);
        sqlite3_free(p);
    }
}

/*
 * TODO Complete this func
 */
static int prepare_predefined_sql_stmt(struct flexi_db_context *pDBEnv, int idx) {
    if (pDBEnv->pStmts[idx] == NULL) {
        char *zSQL;
        switch (idx) {
            case STMT_INS_NAME:
                break;
            case STMT_SEL_CLS_BY_NAME:
                break;
            case STMT_DEL_PROP:
                break;
            case STMT_INS_OBJ:
                break;
            default:
                break;

        }
    }

    return SQLITE_OK;
}


void flexi_vtab_free(struct flexi_vtab *vtab) {
    if (vtab != NULL) {
        if (vtab->pProps != NULL) {
            for (int idx = 0; idx < vtab->nCols; idx++) {
                flexi_vtab_prop_free(&vtab->pProps[idx]);
            }
        }

//        sqlite3_free(vtab->pSortedProps);
        sqlite3_free(vtab->pProps);
        sqlite3_free((void *) vtab->zHash);

        sqlite3_free(vtab);
    }
}

/*
 * Gets name ID by value. Name is expected to exist
 */
 int db_get_name_id(struct flexi_db_context *pDBEnv,
                          const char *zName, sqlite3_int64 *pNameID) {
    if (pNameID) {
        sqlite3_stmt *p = pDBEnv->pStmts[STMT_SEL_NAME_ID];
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
        (struct flexi_db_context *pDBEnv,
         sqlite3_int64 lClassID, sqlite3_int64 lPropNameID, sqlite3_int64 *plPropID) {
    assert(plPropID);

    sqlite3_stmt *p = pDBEnv->pStmts[STMT_SEL_PROP_ID];
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
int db_insert_name(struct flexi_db_context *pDBEnv, const char *zName, sqlite3_int64 *pNameID) {
    assert(zName);
    {
        sqlite3_stmt *p = pDBEnv->pStmts[STMT_INS_NAME];
        assert(p);
        sqlite3_reset(p);
        sqlite3_bind_text(p, 1, zName, -1, NULL);
        int stepRes = sqlite3_step(p);
        if (stepRes != SQLITE_DONE)
            return stepRes;
    }

    int result = db_get_name_id(pDBEnv, zName, pNameID);

    return result;
}

/*
 * Cleans up Flexilite module environment (prepared SQL statements etc.)
 */
 void flexi_db_context_free(struct flexi_db_context *pDBEnv) {
    // Release prepared SQL statements
    for (int ii = 0; ii <= STMT_DEL_FTS; ii++) {
        if (pDBEnv->pStmts[ii])
            sqlite3_finalize(pDBEnv->pStmts[ii]);
    }

    if (pDBEnv->pMatchFuncSelStmt != NULL) {
        sqlite3_finalize(pDBEnv->pMatchFuncSelStmt);
        pDBEnv->pMatchFuncSelStmt = NULL;
    }

    if (pDBEnv->pMatchFuncInsStmt != NULL) {
        sqlite3_finalize(pDBEnv->pMatchFuncInsStmt);
        pDBEnv->pMatchFuncInsStmt = NULL;
    }

    if (pDBEnv->pMemDB != NULL) {
        sqlite3_close(pDBEnv->pMemDB);
        pDBEnv->pMemDB = NULL;
    }

    flexi_free_user_info(pDBEnv->pCurrentUser);

    /*
     *TODO Check 2nd param
     */
    duk_free(pDBEnv->pDuk, NULL);

    memset(pDBEnv, 0, sizeof(*pDBEnv));
}


/*
 * Sorts flexi_vtab->pSortedProps, using bubble sort (should be good enough for this case as we expect only 2-3 dozens of items, at most).
 */
//static void flexi_sort_cols_by_prop_id(struct flexi_vtab *vtab)
//{
//    for (int i = 0; i < vtab->nCols; i++)
//    {
//        for (int j = 0; j < (vtab->nCols - i - 1); j++)
//        {
//            if (vtab->pSortedProps[j].iPropID > vtab->pSortedProps[j + 1].iPropID)
//            {
//                struct flexi_prop_col_map temp = vtab->pSortedProps[j];
//                vtab->pSortedProps[j] = vtab->pSortedProps[j + 1];
//                vtab->pSortedProps[j + 1] = temp;
//            }
//        }
//    }
//}

/*
 * Performs binary search on sorted array of propertyID-column index map.
 * Returns index in vtab->pCols array or -1 if not found
 */
//static int flex_get_col_idx_by_prop_id(struct flexi_vtab *vtab, sqlite3_int64 iPropID)
//{
//    int low = 1;
//    int mid;
//    int high = vtab->nCols;
//    do
//    {
//        mid = (low + high) / 2;
//        if (iPropID < vtab->pSortedProps[mid].iPropID)
//            high = mid - 1;
//        else
//            if (iPropID > vtab->pSortedProps[mid].iPropID)
//                low = mid + 1;
//    } while (iPropID != vtab->pSortedProps[mid].iPropID && low <= high);
//    if (iPropID == vtab->pSortedProps[mid].iPropID)
//    {
//        return mid;
//    }
//
//    return -1;
//}

