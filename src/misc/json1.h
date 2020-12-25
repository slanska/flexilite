//
// Created by slanska on 2016-03-13.
//

#ifndef SQLITE_EXTENSIONS_JSON1_H
#define SQLITE_EXTENSIONS_JSON1_H

#include "../common/common.h"

#include <sqlite3ext.h>

#ifdef __cplusplus
extern "C" {
#endif

/* JSON type values
*/
#define JSON_NULL     0
#define JSON_TRUE     1
#define JSON_FALSE    2
#define JSON_INT      3
#define JSON_REAL     4
#define JSON_STRING   5
#define JSON_ARRAY    6
#define JSON_OBJECT   7

typedef sqlite3_uint64 u64;

/* Bit values for the JsonNode.jnFlag field
*/
#define JNODE_RAW     0x01         /* Content is raw, not JSON encoded */
#define JNODE_ESCAPE  0x02         /* Content is text with \ escapes */
#define JNODE_REMOVE  0x04         /* Do not output */
#define JNODE_REPLACE 0x08         /* Replace with JsonNode.iVal */
#define JNODE_APPEND  0x10         /* More ARRAY/OBJECT entries at u.iAppend */
#define JNODE_LABEL   0x20         /* Is a label of an object */

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
    /* One of the JSON_ type values */
    u8 eType;

    /* JNODE flags */
    u8 jnFlags;

    /* Replacement value when JNODE_REPLACE */
    u8 iVal;

    /* Bytes of content, or number of sub-nodes */
    u32 n;

    union
    {
        /* Content for INT, REAL, and STRING */
        const char *zJContent;

        /* More terms for ARRAY and OBJECT */
        u32 iAppend;

        /* Key for ARRAY objects in json_tree() */
        u32 iKey;
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
 * Initialize the JsonString object
*/
void jsonInit(JsonString *p, sqlite3_context *pCtx);

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

/*
** Do a node lookup using zPath.  Return a pointer to the node on success.
** Return NULL if not found or if there is an error.
**
** On an error, write an error message into pCtx and increment the
** pParse->nErr counter.
**
** If pApnd!=NULL then try to append missing nodes and set *pApnd = 1 if
** nodes are appended.
*/
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

int jsonSetValue(sqlite3_context *ctx,
                 JsonParse *x,
                 const char *zPath,
                 int index,
                 int bIsSet);

/*
** Convert the JsonNode pNode into a pure JSON string and
** append to pOut.  Subsubstructure is also included.  Return
** the number of JsonNode objects that are encoded.
*/
void jsonRenderNode(
        JsonNode *pNode,               /* The node to render */
        JsonString *pOut,              /* Write JSON here */
        sqlite3_value **aReplace       /* Replacement values */
);

/*
** Compute the parentage of all nodes in a completed parse.
*/
int jsonParseFindParents(JsonParse *pParse);

/*
** Search along zPath to find the node specified.  Return a pointer
** to that node, or NULL if zPath is malformed or if there is no such
** node.
**
** If pApnd!=0, then try to append new nodes to complete zPath if it is
** possible to do so and if no existing node corresponds to zPath.  If
** new nodes are appended *pApnd is set to 1.
*/
JsonNode *jsonLookupStep(
        JsonParse *pParse,      /* The JSON to search */
        u32 iRoot,              /* Begin the search at this node */
        const char *zPath,      /* The path to search */
        int *pApnd,             /* Append nodes to complete path if not NULL */
        const char **pzErr      /* Make *pzErr point to any syntax error in zPath */
);

#ifdef __cplusplus
}
#endif

#endif //SQLITE_EXTENSIONS_JSON1_H
