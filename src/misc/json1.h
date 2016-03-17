//
// Created by slanska on 2016-03-13.
//

#ifndef SQLITE_EXTENSIONS_JSON1_H
#define SQLITE_EXTENSIONS_JSON1_H

#include "../../lib/sqlite/sqlite3ext.h"

#ifndef SQLITE_AMALGAMATION
/* Unsigned integer types.  These are already defined in the sqliteInt.h,
** but the definitions need to be repeated for separate compilation. */
typedef sqlite3_uint64 u64;
typedef unsigned int u32;
typedef unsigned char u8;
#endif

/* Objects */
typedef struct JsonString JsonString;
typedef struct JsonNode JsonNode;
typedef struct JsonParse JsonParse;

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
