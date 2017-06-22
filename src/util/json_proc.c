//
// Created by slanska on 2017-02-10.
//

/*
 * Implements simple JSON parser and renderer based on SQLite JSON1 extension
 * (in ../misc/json1.c)
 */

#include "json_proc.h"

SQLITE_EXTENSION_INIT3

typedef struct _JsonNode
{
    struct RBNode hdr;
    JsonNode_t d;
} _JsonNode;

static int
_JsonNode_comparer(const RBNode *a, const RBNode *b, void *arg)
{
    UNUSED_PARAM(arg);
    _JsonNode *aa = (void *) a;
    _JsonNode *bb = (void *) b;
    sqlite3_int64 diff = aa->d.parent - bb->d.parent;
    if (diff == 0)
    {
        const char *zA = aa->d.zKey;
        const char *zB = bb->d.zKey;
        if (zA == NULL)
            zA = "";
        if (zB == NULL)
            zB = "";
        diff = strcmp(zA, zB);
    }
    return (int) diff;
}

static void
_JsonNode_combiner(RBNode *existing, const RBNode *newdata, void *arg)
{
    _JsonNode *from = (void *) existing;
    _JsonNode *to = (void *) newdata;
    to->d = from->d;
    to->d.pValue = sqlite3_value_dup(from->d.pValue);
    String_copy(from->d.zKey, (char **) &to->d.zKey);
    String_copy(from->d.zFullKey, (char **) &to->d.zFullKey);
    String_copy(from->d.zPath, (char **) &to->d.zPath);
}

static RBNode *
_JsonNode_alloc(void *arg)
{
    _JsonNode *result;
    result = sqlite3_malloc(sizeof(_JsonNode));
    memset(result, 0, sizeof(*result));
    return &result->hdr;
}

static void
_JsonNode_free(RBNode *x, void *arg)
{
    if (x == NULL)
        return;

    _JsonNode *node = (void *) x;
    sqlite3_free((void *) node->d.zFullKey);
    sqlite3_free((void *) node->d.zKey);
    sqlite3_free((void *) node->d.zPath);
    sqlite3_value_free(node->d.pValue);
}

void JsonProcessor_init(JsonProcessor_t *self, flexi_Context_t *pCtx)
{
    memset(self, 0, sizeof(*self));
    self->pCtx = pCtx;
    rb_create(&self->nodes, sizeof(_JsonNode), _JsonNode_comparer, _JsonNode_combiner, _JsonNode_alloc,
              _JsonNode_free, self);
    StringBuilder_init(&self->sb);
    Array_init(&self->parentIds, sizeof(intptr_t), NULL);
}

void JsonProcessor_clear(JsonProcessor_t *self)
{
    if (self != NULL)
    {
        rb_clear(&self->nodes);
        StringBuilder_clear(&self->sb);
        Array_clear(&self->parentIds);
    }
}

int JsonProcessor_parse(JsonProcessor_t *self, const char *zInJzon)
{
    int result;

    sqlite3_stmt *pDataSource = NULL;
    _JsonNode *node = NULL;

    /*
     * Parse data JSON
     */
    CHECK_STMT_PREPARE(self->pCtx->db,
                       "select "
                               "key, " // 0
                               "value, " // 1
                               "type, " // 2
                               "atom, " // 3
                               "id, " // 4
                               "parent, " // 5
                               "fullkey, " // 6
                               "path " // 7
                               "from json_tree(:1);", &pDataSource);
    CHECK_CALL(sqlite3_bind_text(pDataSource, 1, zInJzon, -1, NULL));

    while ((result = sqlite3_step(pDataSource)) == SQLITE_ROW)
    {
        _JsonNode_free(&node->hdr, self);
        node = (void *) _JsonNode_alloc(self);
        String_copy((const char *) sqlite3_column_text(pDataSource, 0), (void *) &node->d.zKey);
        node->d.pValue = sqlite3_value_dup(sqlite3_column_value(pDataSource, 1));

        static struct
        {
            const char *zType;
            char type;
        } zJsonTypes[] = {{"object",  JSON_OBJECT},
                          {"integer", JSON_INT},
                          {"real",    JSON_REAL},
                          {"text",    JSON_STRING},
                          {"null",    JSON_NULL},
                          {"array",   JSON_ARRAY},
                          {"true",    JSON_TRUE},
                          {"false",   JSON_FALSE}
        };

        const char *zType = (const char *) sqlite3_column_text(pDataSource, 2);
        for (int ii = 0; ii < ARRAY_LEN(zJsonTypes); ii++)
        {
            if (strcmp(zJsonTypes[ii].zType, zType) == 0)
            {
                node->d.type = zJsonTypes[ii].type;
                break;
            }
        }
        node->d.atom = sqlite3_column_int(pDataSource, 3) != 0;
        node->d.id = sqlite3_column_int64(pDataSource, 4);
        node->d.parent = sqlite3_column_int64(pDataSource, 5);
        String_copy((const char *) sqlite3_column_text(pDataSource, 6), (void *) &node->d.zFullKey);
        String_copy((const char *) sqlite3_column_text(pDataSource, 7), (void *) &node->d.zPath);
        bool isNew;
        rb_insert(&self->nodes, &node->hdr, &isNew);
        Array_setNth(&self->parentIds, (u32)node->d.id, &node->d.parent);
    }

    if (result != SQLITE_ROW && result != SQLITE_DONE)
        goto ONERROR;

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    _JsonNode_free(&node->hdr, self);
    sqlite3_finalize(pDataSource);
    return result;
}

int JsonProcessor_stringify(JsonProcessor_t *self, char **pzOutJson)
{
    // TODO
    return SQLITE_OK;
}

/*
 *
 */
bool JsonProcessor_find(JsonProcessor_t *self, const char *zFullKey, JsonIterator_t *pIterator)
{
    _JsonNode n = {.d = {}};
    pIterator->pJP = self;

    _JsonNode *result = (void *) rb_find(&self->nodes, &n.hdr);

    pIterator->rbi.is_over = result != NULL;
    pIterator->rbi.last_visited = NULL;
    pIterator->rbi.rb = &self->nodes;

    if (result == NULL)
        return false;

    pIterator->pCurrent = &result->d;
    pIterator->rbi.last_visited = &result->hdr;

    return true;
}

bool JsonProcessor_first(JsonProcessor_t *self, const char *zFullKey, JsonIterator_t *pIterator)
{
    rb_begin_left_right_walk(&self->nodes, &pIterator->rbi);
    pIterator->pJP = self;
    pIterator->pCurrent = &((_JsonNode *) pIterator->rbi.last_visited)->d;
    return !pIterator->rbi.is_over;
}

bool JsonProcessor_next(JsonIterator_t *pIterator)
{
    RBNode *n = rb_right_left_walk(&pIterator->rbi);
    if (n == NULL)
    {
        pIterator->pCurrent = NULL;
        return false;
    }

    pIterator->pCurrent = &((_JsonNode *) pIterator->rbi.last_visited)->d;
    return true;
}