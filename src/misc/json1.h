//
// Created by slanska on 2016-03-13.
//

#ifndef SQLITE_EXTENSIONS_JSON1_H
#define SQLITE_EXTENSIONS_JSON1_H

//#include "../../lib/sqlite/sqlite3ext.h"

#ifndef SQLITE_AMALGAMATION
/* Unsigned integer types.  These are already defined in the sqliteInt.h,
** but the definitions need to be repeated for separate compilation. */
typedef sqlite3_uint64 u64;
typedef unsigned int u32;
typedef unsigned char u8;
#endif

/* Objects */
/* An instance of this object represents a JSON string
** under construction.  Really, this is a generic string accumulator
** that can be and is used to create strings other than JSON.
*/
struct JsonString
{
    sqlite3_context *pCtx;
    /* Function context - put error messages here */
    char *zBuf;
    /* Append JSON content here */
    u64 nAlloc;
    /* Bytes of storage available in zBuf[] */
    u64 nUsed;
    /* Bytes of zBuf[] currently used */
    u8 bStatic;
    /* True if zBuf is static space */
    u8 bErr;
    /* True if an error has been encountered */
    char zSpace[100];        /* Initial static space */
};

typedef struct JsonString JsonString;
typedef struct JsonString StringBuilder;
typedef struct JsonNode JsonNode;
typedef struct JsonParse JsonParse;

/* Initialize the JsonString object
*/
void jsonInit(JsonString *p, sqlite3_context *pCtx);

/* Append the N-byte string in zIn to the end of the JsonString string
** under construction.  Enclose the string in "..." and escape
** any double-quotes or backslash characters contained within the
** string.
*/
void jsonAppendString(JsonString *p, const char *zIn, u32 N);

/* Append N bytes from zIn onto the end of the JsonString string.
*/
void jsonAppendRaw(JsonString *p, const char *zIn, u32 N);

/* Free all allocated memory and reset the JsonString object back to its
** initial state.
*/
void jsonReset(JsonString *p);

/* A single node of parsed JSON
*/
struct JsonNode
{
    u8 eType;
    /* One of the JSON_ type values */
    u8 jnFlags;
    /* JNODE flags */
    u8 iVal;
    /* Replacement value when JNODE_REPLACE */
    u32 n;
    /* Bytes of content, or number of sub-nodes */
    union
    {
        const char *zJContent;
        /* Content for INT, REAL, and STRING */
        u32 iAppend;
        /* More terms for ARRAY and OBJECT */
        u32 iKey;              /* Key for ARRAY objects in json_tree() */
    } u;
};

/* A completely parsed JSON string
*/
struct JsonParse
{
    u32 nNode;
    /* Number of slots of aNode[] used */
    u32 nAlloc;
    /* Number of slots of aNode[] allocated */
    JsonNode *aNode;
    /* Array of nodes containing the parse */
    const char *zJson;
    /* Original JSON string */
    u32 *aUp;
    /* Index of parent of each node */
    u8 oom;
    /* Set to true if out of memory */
    u8 nErr;           /* Number of errors seen */
};

/*
** Parse a complete JSON string.  Return 0 on success or non-zero if there
** are any errors.  If an error occurs, free all memory associated with
** pParse.
**
** pParse is uninitialized when this routine is called.
*/
int jsonParse(
        JsonParse *pParse,           /* Initialize and fill this JsonParse object */
        sqlite3_context *pCtx,       /* Report errors here */
        const char *zJson            /* Input JSON text to be parsed */
);

JsonNode *jsonLookup(
        JsonParse *pParse,      /* The JSON to search */
        const char *zPath,      /* The path to search */
        int *pApnd,             /* Append nodes to complete path if not NULL */
        sqlite3_context *pCtx   /* Report errors here, if not NULL */
);

void jsonParseReset(JsonParse *pParse);

/*
 * Retrieves value from JSON node and sets to the context
 */
void jsonReturn(
        JsonNode *pNode,            /* Node to return */
        sqlite3_context *pCtx,      /* Return value for this function */
        sqlite3_value **aReplace    /* Array of replacement values */
);



#endif //SQLITE_EXTENSIONS_JSON1_H
