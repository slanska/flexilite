//
// Created by slanska on 2016-04-08.
//

#include <string.h>
#include <printf.h>
#include <assert.h>
#include "../../lib/sqlite/sqlite3ext.h"
#include "../../src/misc/json1.h"

SQLITE_EXTENSION_INIT3

/*
 * Internally used structures, subclassed from SQLite structs
 */

struct flexi_vtab
{
    unsigned char base[sizeof(sqlite3_vtab)];
    sqlite3 *db;
    sqlite3_int64 iClassID;
};

struct flexi_column_data
{
    sqlite3_int64 lPropID;
    sqlite3_int64 lPropIdx;
    int ctlv;
    sqlite3_value *pVal;
};

struct flexi_vtab_cursor
{
    unsigned char base[sizeof(struct sqlite3_vtab_cursor)];
    sqlite3_stmt *pObjectIterator;
    sqlite3_stmt *pPropertyIterator;
    sqlite3_int64 lObjectID;

    /*
     * Number of columns/properties
     */
    int iCol;

    /*
     * Actually fetched number of column values.
     * Reset to 0 on every next object fetch
     */
    int iReadCol;

    /*
     * Array of column data, by their index
     */
    struct flexi_column_data *pCols;


    int bEof;
};

#define strAppend(SB, S)    jsonAppendRaw(SB, S, strlen(S))
#define strFree(SB)         jsonReset(SB)

/*
 * Creates new class
 */
static int flexiEavCreate(sqlite3 *db,
        // User data
                          void *pAux,
                          int argc,

        // argv[0] - module name
        // argv[1] - database name ("main", "temp" etc.)
        // argv [2] - name of new table (class)
        // argv[3+] - arguments (property specifications/column declarations)
                          const char *const *argv,

        // Result of function - table spec
                          sqlite3_vtab **ppVTab,
                          char **pzErr)
{
    StringBuilder *zCreate = sqlite3_malloc(sizeof(StringBuilder));
    jsonInit(zCreate, NULL);

    // TODO insert into .classes

    strAppend(zCreate, "create table [");
    strAppend(zCreate, argv[2]);
    strAppend(zCreate, "] (");

    // TODO For now just iterate through column definition and append them to the CREATE TABLE
    for (int idx = 3; idx < argc; idx++)
    {
        if (idx != 3)
            strAppend(zCreate, ",");
        strAppend(zCreate, argv[idx]);

        // TODO insert into .class_properties
    }
    strAppend(zCreate, ");");

    zCreate->zBuf[zCreate->nUsed] = 0;
    int result = sqlite3_declare_vtab(db, zCreate->zBuf);

    strFree(zCreate);

    if (result == SQLITE_OK)
    {
        struct flexi_vtab *vtab = sqlite3_malloc(sizeof(struct flexi_vtab));
        if (vtab == NULL)
            return SQLITE_NOMEM;
        *ppVTab = (void *) vtab;
        memset(vtab, 0, sizeof(*vtab));
        vtab->db = db;
    }

    return result;

}

/* Connects to flexi_eav virtual table. */
static int flexiEavConnect(
        sqlite3 *db,

        // User data
        void *pAux,
        int argc, const char *const *argv,
        sqlite3_vtab **ppVtab,
        char **pzErr
)
{
    // TODO Temp
    int result = flexiEavCreate(db, pAux, argc, argv, ppVtab, pzErr);
    return result;
}

/*
 *
 */
static int flexiEavDisconnect(sqlite3_vtab *pVTab)
{
    sqlite3_free(pVTab);
    return SQLITE_OK;
}

/*
 * Finds best existing index for the given criteria, based on index definition for class' properties
 *   struct sqlite3_index_info {
 *   */
// Inputs
//const int nConstraint;     /* Number of entries in aConstraint */
//const struct sqlite3_index_constraint {
//    int iColumn;              /* Column constrained.  -1 for ROWID */
//    unsigned char op;         /* Constraint operator */
//    unsigned char usable;     /* True if this constraint is usable */
//    int iTermOffset;          /* Used internally - xBestIndex should ignore */
//} *const aConstraint;      /* Table of WHERE clause constraints */
//const int nOrderBy;        /* Number of terms in the ORDER BY clause */
//const struct sqlite3_index_orderby {
//    int iColumn;              /* Column number */
//    unsigned char desc;       /* True for DESC.  False for ASC. */
//} *const aOrderBy;         /* The ORDER BY clause */
//
///* Outputs */
//struct sqlite3_index_constraint_usage {
//    int argvIndex;           /* if >0, constraint is part of argv to xFilter */
//    unsigned char omit;      /* Do not code a test for this constraint */
//} *const aConstraintUsage;
//int idxNum;                /* Number used to identify the index */
//char *idxStr;              /* String, possibly obtained from sqlite3_malloc */
//int needToFreeIdxStr;      /* Free idxStr using sqlite3_free() if true */
//int orderByConsumed;       /* True if output is already ordered */
//double estimatedCost;      /* Estimated cost of using this index */
///* Fields below are only available in SQLite 3.8.2 and later */
//sqlite3_int64 estimatedRows;    /* Estimated number of rows returned */
///* Fields below are only available in SQLite 3.9.0 and later */
//int idxFlags;              /* Mask of SQLITE_INDEX_SCAN_* flags */
///* Fields below are only available in SQLite 3.10.0 and later */
//sqlite3_uint64 colUsed;    /* Input: Mask of columns used by statement */
//};

static int flexiEavBestIndex(
        sqlite3_vtab *tab,
        sqlite3_index_info *pIdxInfo
)
{
#define SQLITE_INDEX_CONSTRAINT_EQ      2
#define SQLITE_INDEX_CONSTRAINT_GT      4
#define SQLITE_INDEX_CONSTRAINT_LE      8
#define SQLITE_INDEX_CONSTRAINT_LT     16
#define SQLITE_INDEX_CONSTRAINT_GE     32
#define SQLITE_INDEX_CONSTRAINT_MATCH  64
#define SQLITE_INDEX_CONSTRAINT_LIKE   65     /* 3.10.0 and later only */
#define SQLITE_INDEX_CONSTRAINT_GLOB   66     /* 3.10.0 and later only */
#define SQLITE_INDEX_CONSTRAINT_REGEXP 67     /* 3.10.0 and later only */
#define SQLITE_INDEX_SCAN_UNIQUE        1     /* Scan visits at most 1 row */

    // Get class info
    // Find property by column index
    // Check if property is indexed or not
    // Check if property is nullable or not

    // For simple ops (==, <= etc.) try to apply index

    // For match, like and glob - try to apply full text index, if applicable

    // For regexp - will do scan

    return SQLITE_OK;

}

/*
 * Delete class
 */
static int flexiEavDestroy(sqlite3_vtab *pVTab)
{
    //pVTab->pModule
    // TODO "delete from [.classes] where NameID = "
    return SQLITE_OK;
}

/*
 * Starts SELECT on a Flexilite class
 */
static int flexiEavOpen(sqlite3_vtab *pVTab, sqlite3_vtab_cursor **ppCursor)
{
    // Cursor will have 2 prepared sqlite statements: 1) find object IDs by property values (either with index or not), 2) to iterate through found objects' properties
    struct flexi_vtab_cursor *cur = sqlite3_malloc(sizeof(struct flexi_vtab_cursor));
    if (cur == NULL)
        return SQLITE_NOMEM;

    *ppCursor = (void *) cur;
    memset(cur, 0, sizeof(*cur));

    cur->bEof = 0;
    cur->lObjectID = -1;
    struct flexi_vtab *vtab = (void *) pVTab;
    const char *zObjSql = "select ObjectID, ClassID, ctlo from [.objects]";
    int result = sqlite3_prepare_v2(vtab->db, zObjSql, (int) strlen(zObjSql), &cur->pObjectIterator, NULL);
    if (result == SQLITE_OK)
    {
        const char *zPropSql = "select * from [.ref-values] where ObjectID = $ObjectID";
        result = sqlite3_prepare_v2(vtab->db, zPropSql, (int) strlen(zPropSql), &cur->pPropertyIterator, NULL);
    }

    return result;
}

/*
 * Finishes SELECT
 */
static int flexiEavClose(sqlite3_vtab_cursor *pCursor)
{
    struct flexi_vtab_cursor *cur = (void *) pCursor;
    sqlite3_finalize(cur->pObjectIterator);
    sqlite3_finalize(cur->pPropertyIterator);
    sqlite3_free(pCursor);
    return SQLITE_OK;
}

/*
 * Begins search
 * idxNum will have indexed property ID
 */
static int flexiEavFilter(sqlite3_vtab_cursor *pCursor, int idxNum, const char *idxStr,
                          int argc, sqlite3_value **argv)
{
    return SQLITE_OK;
}

/*
 * Advances to the next found object
 */
static int flexiEavNext(sqlite3_vtab_cursor *pCursor)
{
    struct flexi_vtab_cursor *cur = (void *) pCursor;
    int result = sqlite3_step(cur->pObjectIterator);
    if (result == SQLITE_DONE)
    {
        cur->bEof = 1;
        return SQLITE_OK;
    }

    if (result == SQLITE_ROW)
    {
        cur->lObjectID = sqlite3_column_int64(cur->pObjectIterator, 0);
        cur->iReadCol = 0;
        return SQLITE_OK;
    }

    return result;
}

/*
 * Returns 0 if EOF is not reached yet. 1 - if EOF (all rows processed)
 */
static int flexiEavEof(sqlite3_vtab_cursor *pCursor)
{
    struct flexi_vtab_cursor *cur = (void *) pCursor;
    return cur->bEof;
}

/*
 * Returns value for the column at position iCol (starting from 0).
 * Can use the following APIs:
sqlite3_result_blob()
sqlite3_result_double()
sqlite3_result_int()
sqlite3_result_int64()
sqlite3_result_null()
sqlite3_result_text()
sqlite3_result_text16()
sqlite3_result_text16le()
sqlite3_result_text16be()
sqlite3_result_zeroblob()
 *
 */
static int flexiEavColumn(sqlite3_vtab_cursor *pCursor, sqlite3_context *pContext, int iCol)
{
    struct flexi_vtab_cursor *cur = (void *) pCursor;

    // First, check if column has been already loaded
    if (cur->iReadCol >= iCol + 1)
    {
        sqlite3_result_value(pContext, cur->pCols[iCol].pVal);
        return SQLITE_OK;
    }

    sqlite3_step(cur->pPropertyIterator);

    // Map column number to property ID
    return SQLITE_OK;
}

/*
 * Returns object ID into pRowID
 */
static int flexiEavRowId(sqlite3_vtab_cursor *pCursor, sqlite_int64 *pRowid)
{
    struct flexi_vtab_cursor *cur = (void *) pCursor;
    *pRowid = cur->lObjectID;
    return SQLITE_OK;
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
static int flexiEavUpdate(sqlite3_vtab *pVTab, int argc, sqlite3_value **argv, sqlite_int64 *pRowid)
{
    return SQLITE_OK;
}

/*
 * Renames class to a new name (zNew)
 */
static int flexiEavRename(sqlite3_vtab *pVtab, const char *zNew)
{
    struct flexi_vtab *pTab = (void *) pVtab;
    const char *zSql = "insert or replace into [.names] (NameID, [Value]) select NameID, $Value from [.names] where Value = $Value limit 1;" \
        "update [.classes] set NameID = $NameID where ClassID = $ClassID;";

    const char *zErrMsg;
    sqlite3_stmt *pStmt;
    int result = sqlite3_prepare_v2(pTab->db, zSql, (int) strlen(zSql), &pStmt, &zErrMsg);
    if (result == SQLITE_OK)
    {
// TODO sqlite3_bind_int64(pStmt, 0,)
    }

    return result;
}


/* The methods of the json_each virtual table */
static sqlite3_module flexiEavModule = {
        0,                         /* iVersion */
        flexiEavCreate,            /* xCreate */
        flexiEavConnect,           /* xConnect */
        flexiEavBestIndex,         /* xBestIndex */
        flexiEavDisconnect,        /* xDisconnect */
        flexiEavDestroy,           /* xDestroy */
        flexiEavOpen,              /* xOpen - open a cursor */
        flexiEavClose,             /* xClose - close a cursor */
        flexiEavFilter,            /* xFilter - configure scan constraints */
        flexiEavNext,              /* xNext - advance a cursor */
        flexiEavEof,               /* xEof - check for end of scan */
        flexiEavColumn,            /* xColumn - read data */
        flexiEavRowId,             /* xRowid - read data */
        flexiEavUpdate,            /* xUpdate */
        0,                         /* xBegin */
        0,                         /* xSync */
        0,                         /* xCommit */
        0,                         /* xRollback */
        0,                         /* xFindMethod */
        flexiEavRename,            /* xRename */
        0,                         /* xSavepoint */
        0,                         /* xRelease */
        0                          /* xRollbackTo */
};

static void flexiEavModuleDestroy(void *data)
{

}

int sqlite3_flexieav_vtable_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
)
{
    void *data = NULL; // TODO
    int result = sqlite3_create_module_v2(db, "flexi_eav", &flexiEavModule, data, flexiEavModuleDestroy);
    return result;
}