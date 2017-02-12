//
// Created by slanska on 2017-02-10.
//

/*
 * Implements simple JSON parser and renderer based on SQLite JSON1 extension
 * (in ../misc/json1.c)
 */

#include "json_proc.h"
#include "../project_defs.h"

SQLITE_EXTENSION_INIT3

static void _free_value(void *elem) {
    char *pp = *(char *) elem;
    sqlite3_free((void *) *pp);
}

int json_parse(JSON_Processor *json, sqlite3_context *pCtx, const char *zJSON) {
    int result = SQLITE_OK;

    memset(json, 0, sizeof(*json));
    jsonParse(&json->parser, pCtx, zJSON);
    jsonInit(&json->out, pCtx);
    buffer_init(&json->nodeValues, sizeof(sqlite3_value), _free_value);

    return result;
}

JsonNode *json_root(JSON_Processor *json) {
    return json->parser.aNode;
}

void json_stringify(JSON_Processor *json, char **pzOut) {
    json_n_stringify(json, json->parser.aNode, pzOut);
}

void json_n_stringify(JSON_Processor *json, JsonNode *pNode, char **pzOut) {
    jsonRenderNode(pNode, &json->out, NULL);
    size_t len = strlen(json->out.zBuf);
    *pzOut = sqlite3_malloc((int) len + 1);
    memcpy(*pzOut, json->out.zBuf, len + 1);
}

JsonNode *json_get(JSON_Processor *json, const char *zPath) {
    int iApnd = 0;
    JsonNode *result = jsonLookup(&json->parser, zPath, &iApnd, json->out.pCtx);
    return result;
}

JsonNode *json_n_get(JSON_Processor *json, JsonNode *pRoot, const char *zPath) {
    int iApnd = 0;
    const char *pzErr;
    JsonNode *result = jsonLookupStep(&json->parser, pRoot->n, zPath, &iApnd, &pzErr);
    if (*pzErr)
        return NULL;

    return result;
}

JsonNode *json_set(JSON_Processor *json, const char *zPath, sqlite3_value *val) {
    int iApnd = 1;
    JsonNode *result = jsonLookup(&json->parser, zPath, &iApnd, json->out.pCtx);
    int len = sqlite3_value_bytes(val);
    char *zValue = sqlite3_malloc(len);
    strncpy(zValue, sqlite3_value_text(val), len - 1);
    // TODO When zValue will be disposed?
    result->u.zJContent = zValue;
    return result;
}

void json_dispose(JSON_Processor *json) {
    jsonReset(&json->out);
    jsonParseReset(&json->parser);
}
