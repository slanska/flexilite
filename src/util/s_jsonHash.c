//
// Created by slanska on 2017-01-22.
//

/*
 * General purpose class which parses JSON string and provides fast access to parsed JSON.
 * Uses JSON functionality from SQLite JSON extension, specifically json_tree
 * Calls json_tree, then iterates over rows and populates internal structure for fast access
 */

#include <stddef.h>
#include <sqlite3ext.h>
#include "../util/hash.h"

SQLITE_EXTENSION_INIT3

typedef struct s_jsonHash {
    int linkCount;
    struct s_jsonElemLink *links;
    Hash *pathMap;
} s_jsonHash;

typedef const char *string;

s_jsonHash *s_jsonHash_new() {
    // TODO
    return 0;
}

typedef struct s_JsonElem {
    int id;
    int parent;
    sqlite3_value *key;
    sqlite3_value *atom;
    char *fullKey;
    char *path;
} s_JsonElem;

typedef struct s_jsonElemLink {
    struct s_jsonElemLink *parent;
    struct s_jsonElemLink *firstChild;
    struct s_jsonElemLink *nextSibling;
    s_JsonElem *elem;
} s_jsonElemLink;

void s_jsonHash_done(
        s_jsonHash *hash) {}

int s_jsonHash_parse(
        s_jsonHash *hash,
        const char *json) {
    return SQLITE_OK;
}

s_jsonElemLink *s_jsonHash_getById(
        s_jsonHash *hash,
        const int id) {
    return NULL;
}

s_jsonElemLink *s_jsonHash_getByPath(
        s_jsonHash *hash,
        const char *path) {
    return NULL;
}

s_jsonElemLink *s_jsonHash_firstChild(
        s_jsonHash *hash,
        const s_jsonElemLink *parent) {
    return NULL;
}

s_jsonElemLink *s_jsonHash_nextChild(
        s_jsonHash *hash,
        s_jsonElemLink *prevElem) {
    return NULL;
}
