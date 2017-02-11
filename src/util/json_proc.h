//
// Created by slanska on 2017-02-10.
//

#ifndef FLEXILITE_JSON_PROC_H
#define FLEXILITE_JSON_PROC_H

#include "../project_defs.h"
#include "../misc/json1.h"

struct JSON_Processor {
    JsonParse parser;
    JsonString out;
};

typedef struct JSON_Processor JSON_Processor;

int json_parse(JSON_Processor *json, sqlite3_context *pCtx, const char *zJSON);

JsonNode *json_root(JSON_Processor *json);

void json_stringify(JSON_Processor *json, char **pzOut);

void json_n_stringify(JSON_Processor *json, JsonNode *pNode, char **pzOut);

JsonNode *json_get(JSON_Processor *json, const char *zPath);

JsonNode *json_set(JSON_Processor *json, const char *zPath, sqlite3_value *val);

JsonNode *json_insert(JSON_Processor *json, const char *zPath, sqlite3_value *val);

JsonNode *json_delete(JSON_Processor *json, const char *zPath);

JsonNode *json_n_set(JSON_Processor *json, JsonNode *pBase, const char *zPath, sqlite3_value *val);

int json_child_count(JsonNode *pBase);

void json_dispose(JSON_Processor *json);

#endif //FLEXILITE_JSON_PROC_H
