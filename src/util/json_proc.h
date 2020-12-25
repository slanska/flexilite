//
// Created by slanska on 2017-02-10.
//

#ifndef FLEXILITE_JSON_PROC_H
#define FLEXILITE_JSON_PROC_H

#include "../project_defs.h"
#include "../misc/json1.h"
#include "Array.h"
#include "rbtree.h"
#include "StringBuilder.h"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * JSON processor module
 * Parses and provides fast lookup on JSON elements
 */
typedef struct JsonProcessor_t
{
    flexi_Context_t *pCtx;
    /*
     * Nodes sorted by fullkey
     */
    RBTree nodes;

    /*
     * List of parent IDs corresponding their child IDs
     */
    Array_t parentIds;

    /*
     * Output JSON string builder
     */
    StringBuilder_t sb;

} JsonProcessor_t;

typedef struct JsonNode_t
{
    const char *zFullKey;
    const char *zKey;
    const char *zPath;
    sqlite3_value *pValue;
    sqlite3_int64 id;
    sqlite3_int64 parent;
    bool atom;
    char type; // JSON_*
} JsonNode_t;

typedef struct JsonIterator_t
{
    JsonProcessor_t *pJP;
    JsonNode_t *pCurrent;
    RBIterator rbi;
} JsonIterator_t;

void JsonProcessor_init(JsonProcessor_t *self, flexi_Context_t *pCtx);

void JsonProcessor_clear(JsonProcessor_t *self);

int JsonProcessor_parse(JsonProcessor_t *self, const char *zInJzon);

int JsonProcessor_stringify(JsonProcessor_t *self, char **pzOutJson);

bool JsonProcessor_find(JsonProcessor_t *self, const char *zFullKey, JsonIterator_t *pIterator);

bool JsonProcessor_first(JsonProcessor_t *self, const char *zFullKey, JsonIterator_t *pIterator);

bool JsonProcessor_next(JsonIterator_t *pIterator);

#ifdef __cplusplus
}
#endif

#endif //FLEXILITE_JSON_PROC_H
