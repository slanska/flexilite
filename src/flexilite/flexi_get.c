//
// Created by slanska on 2016-03-13.
//

#include <string.h>
#include <printf.h>
#include "../../lib/sqlite/sqlite3ext.h"
#include "../misc/json1.h"

SQLITE_EXTENSION_INIT3

#include <string.h>

// SQL statement parameters
#define WHERE_PROPERTY_INDEX 1
#define WHERE_VALUE_INDEX 2
#define ORDER_BY_PROPERTY_INDEX 3
#define OBJECT_ID_INDEX 4
#define REF_PROPERTY_INDEX 5
#define PROPINDEX_INDEX 6

// String literals to make SQL declarations shorter and more expressive
#define _SQL_WHERE_BY_PROPERTY_PART_ " flexi_get(?1, SchemaData, Data) = ?2"
#define _SQL_ORDER_BY_PROPERTY_PART_ " order by flexi_get(?3, SchemaData, Data)"
#define _SQL_SELECT_PART_ "select JSON_SET(o.Data, v.Data) as Data, s.Data as SchemaData, s.SchemaID as SchemaID, o.ObjectID as ObjectID"\
    " from [.ref-values] v join [.objects] o on v.ObjectID = o.ObjectID" \
    " left outer join [.schemas] s on o.SchemaID = s.SchemaID"\
    " where v.ObjectID = ?4 and v.PropertyID = ?5 "

/*
 * SQL strings for retrieving linked data, for various cases
 */
static const char *sql_strings[9] =
        {
                // 0 - First item in ref collection, sorted by property index
                _SQL_SELECT_PART_ " order by v.PropIndex asc limit 1;",

                // 1 - First item in ref collection, sorted by 'order-by' property
                "select * from (" _SQL_SELECT_PART_ ") " _SQL_ORDER_BY_PROPERTY_PART_ " asc limit 1;",

                // 2 - Last item in ref collection, sorted by property index
                _SQL_SELECT_PART_ " order by v.PropIndex desc limit 1;",

                // 3 - Last item in reference collection, sorted by 'order-by' property
                "select * from (" _SQL_SELECT_PART_ ") " _SQL_ORDER_BY_PROPERTY_PART_ " desc limit 1;",

                // 4 - First item in ref collection, filtered by 'where' property
                "select * from (" _SQL_SELECT_PART_ ") where " _SQL_WHERE_BY_PROPERTY_PART_ " order by v.PropIndex asc limit 1;",

                // 5 - First item in ref collection, filtered by 'where' property and sorted by 'order-by' property
                "select * from (" _SQL_SELECT_PART_ ") where " _SQL_WHERE_BY_PROPERTY_PART_ _SQL_ORDER_BY_PROPERTY_PART_ " asc limit 1;",

                // 6 - Last item in ref collection, filtered by 'where' property
                "select * from (" _SQL_SELECT_PART_ ") where " _SQL_WHERE_BY_PROPERTY_PART_ " order by v.PropIndex desc limit 1;",

                // 7 - Last item in ref collection, filtered by 'where' property and sorted by 'order-by' property
                "select * from (" _SQL_SELECT_PART_ ") where " _SQL_WHERE_BY_PROPERTY_PART_ _SQL_ORDER_BY_PROPERTY_PART_ " desc limit 1;",

                // 8 - by specific index in reference collection
                _SQL_SELECT_PART_ " and v.PropIndex = ?6 limit 1;"
        };

/*
 * Holds list of prepared statements to speed up 'flexi_get' function
 */
struct flexi_prepared_statements
{
    sqlite3_stmt *statements[9];
};

/*
 *
 */
static JsonNode *jsonGetNode(JsonParse *x, const char *zPathTemplate, int iPropID, sqlite3_context *context)
{
    JsonNode *result;
    char zPropPath[100];
    sprintf(zPropPath, zPathTemplate, (int) iPropID);
    result = jsonLookup(x, zPropPath, 0, context);
    return result;
}

/*
 *
 */
static void setSQLiteParam(sqlite3_stmt *stmt, int paramNo, JsonNode *jsNode)
{
    if (jsNode != NULL && jsNode->u.zJContent != NULL)
    {
        sqlite3_bind_text(stmt, paramNo, jsNode->u.zJContent, 0, 0);
    }
}

struct flexi_get_fetch_params
{
    const unsigned char *schemaJSON;
    const unsigned char *dataJSON;
    long int objectID;
    int schemaID;
};

/*
 * Returns:
0 - search is over. If result is found, then it is set in sqlite3_context. Otherwise, null is set to sqlite3_context
1 - no result yet, but based on schema definition, linked objects may have requested data. fetchParams will
 be set to new set of data
 */
static int flexi_get_value(sqlite3 *db, sqlite3_int64 iPropID, struct flexi_get_fetch_params *fetchParams,
                           struct flexi_prepared_statements *statements, sqlite3_context *context)
{
    int result = 0;

    // Get property definition from schema JSON.
    JsonParse xSchema;          /* The parse */
    JsonParse xData;          /* The parse */

    int parseResult = jsonParse(&xSchema, context, (const char *) fetchParams->schemaJSON);
    if (parseResult != SQLITE_OK)
    {
        // TODO Report schema ID
        sqlite3_result_error(context, "Schema JSON parsing error", parseResult);
        goto EXIT;
    }

    JsonNode *propNode = jsonGetNode(&xSchema, "$.properties.%d.map.jsonPath", (int) iPropID, context);
    if (propNode != NULL && propNode->u.zJContent && strlen(propNode->u.zJContent) > 0)
        // direct mapping was found. Try to get data directly from data JSON
    {
        parseResult = jsonParse(&xData, context, (const char *) fetchParams->dataJSON);
        if (parseResult != SQLITE_OK)
        {
            // TODO sqlite3_result_error(context, "Data JSON parsing error", parseResult);
            goto EXIT;
        }

        char propPath[200];
        strncpy(propPath, propNode->u.zJContent, propNode->n);
        if (propPath[propNode->n - 1] == '\"')
            propPath[propNode->n - 1] = 0;
        char *pPropPath = &propPath[0];
        if (*pPropPath == '\"')
            pPropPath++;
        JsonNode *dataNode = jsonLookup(&xData, pPropPath, 0, context);
        if (dataNode != NULL)
        {
            jsonReturn(dataNode, context, NULL);
            goto EXIT;
        }
    }

    // direct value from data JSON was not retrieved. Try to get data from linked object, if applicable

    // Reference property ID
    JsonNode *refPropNode = jsonGetNode(&xSchema, "$.properties.%d.map.link.refPropID", (int) iPropID, context);
    if (refPropNode == NULL || refPropNode->u.zJContent == NULL)
    {
        goto EXIT;
    }

    // Linked object property ID
    JsonNode *valPropNode = jsonGetNode(&xSchema, "$.properties.%d.map.link.valuePropID", (int) iPropID, context);
    if (valPropNode == NULL || valPropNode->u.zJContent == NULL)
    {
        goto EXIT;
    }

    int stmtIndex = 0;

    // Optional properties
    JsonNode *wherePropNode = NULL;
    JsonNode *whereValuePropNode = NULL;
    JsonNode *sortPropNode = NULL;
    JsonNode *descPropNode = NULL;
    // Property Index
    JsonNode *idxPropNode = jsonGetNode(&xSchema, "$.properties.%d.map.link.propIndex", (int) iPropID, context);
    if (idxPropNode != NULL)
    {
        stmtIndex = 8;
    }
    else
    {
        // Where property ID
        wherePropNode = jsonGetNode(&xSchema, "$.properties.%d.map.link.where.filterPropID", (int) iPropID,
                                    context);

        if (wherePropNode != NULL)
        {
            whereValuePropNode = jsonGetNode(&xSchema, "$.properties.%d.map.link.where.valuePropID", (int) iPropID,
                                             context);
            if (whereValuePropNode == NULL)
            {
                goto EXIT;
            }
            stmtIndex |= 0x04;
        }

        // Sort property ID
        sortPropNode = jsonGetNode(&xSchema, "$.properties.%d.map.link.sort.propID", (int) iPropID, context);
        if (sortPropNode != NULL)
        {
            stmtIndex |= 0x01;
        }

        // Desc property ID
        descPropNode = jsonGetNode(&xSchema, "$.properties.%d.map.link.sort.desc", (int) iPropID, context);
        if (descPropNode != NULL)
            stmtIndex |= 0x02;
    }

    // Check if SQL statement has been already prepared
    if (statements->statements[stmtIndex] == NULL)
    {
        const char *sql = sql_strings[stmtIndex];
        int prepareResult = sqlite3_prepare_v2(db,
                                               sql,
                                               (int) strlen(sql),
                                               &statements->statements[stmtIndex],
                                               NULL);
    }
    else
    {
        sqlite3_reset(statements->statements[stmtIndex]);
    }

    sqlite3_stmt *stmt = statements->statements[stmtIndex];
    sqlite3_reset(stmt);
    setSQLiteParam(stmt, WHERE_PROPERTY_INDEX, wherePropNode);
    setSQLiteParam(stmt, WHERE_VALUE_INDEX, whereValuePropNode);
    setSQLiteParam(stmt, ORDER_BY_PROPERTY_INDEX, sortPropNode);
    setSQLiteParam(stmt, PROPINDEX_INDEX, idxPropNode);
    sqlite3_bind_int64(stmt, OBJECT_ID_INDEX, fetchParams->objectID);
    setSQLiteParam(stmt, REF_PROPERTY_INDEX, refPropNode);

    int exec_result = sqlite3_step(stmt);
    if (exec_result == SQLITE_ROW)
    {
        fetchParams->dataJSON = sqlite3_column_text(stmt, 0);
        fetchParams->schemaJSON = sqlite3_column_text(stmt, 1);
        fetchParams->schemaID = sqlite3_column_int(stmt, 2);
        fetchParams->objectID = sqlite3_column_int64(stmt, 3);
        result = 1;
    }

    EXIT:

    jsonParseReset(&xData);
    jsonParseReset(&xSchema);
    return result;
}

/*
 * Flexilite (https://github.com/slanska/flexilite) specific function.
 * Uses database structure defined in Flexilite database to dynamically process
 * defined data schema and returns actual value for the given property.
 * Process schemas in loop, via linked properties and stops when either value is found, or linked schemas are exhausted.
 * Expects 4 parameters:
 * property ID to retrieve
 * object ID
 * schema JSON1 data
 *      expected to be in the following format, as defined by Flexilite:
 *      properties: {[propID:number]: {map: {jsonPath:string, link: {refPropID: number, wherePropertyID: number;
 *      whereValue: any; orderByPropID: number;
 *      orderByDesc: boolean;
 *      linkedPropID: number}}}}
 * data JSON1 data
  */
static void sqlFlexiGetFunc(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
)
{
    if (argc != 4)
    {
        sqlite3_result_error(context, "Function flexi_get() expects 4 arguments", 1);
        return;
    }

    sqlite3 *db = sqlite3_context_db_handle(context);

    struct flexi_prepared_statements *dataContext = (struct flexi_prepared_statements *) sqlite3_user_data(context);
    const sqlite3_int64 iPropID = sqlite3_value_int64(argv[0]);

    struct flexi_get_fetch_params fetchParams;
    fetchParams.schemaID = -1;
    fetchParams.schemaJSON = sqlite3_value_text(argv[2]);
    fetchParams.objectID = sqlite3_value_int64(argv[1]);
    fetchParams.dataJSON = sqlite3_value_text(argv[3]);

    // Preventive assumption that result is NULL
    sqlite3_result_null(context);

    do
    {
    }
    while (flexi_get_value(db, iPropID, &fetchParams, dataContext, context));
}

#ifdef _WIN32
__declspec(dllexport)
#endif

int sqlite3_flexi_get_init(
        sqlite3 *db,
        char **pzErrMsg,
        const sqlite3_api_routines *pApi
)
{
    int rc = SQLITE_OK;
    SQLITE_EXTENSION_INIT2(pApi);
    (void) pzErrMsg;  /* Unused parameter */

    struct flexi_prepared_statements *data = sqlite3_malloc(sizeof(struct flexi_prepared_statements));
    rc = sqlite3_create_function_v2(db, "flexi_get", 4, SQLITE_UTF8, data,
                                    sqlFlexiGetFunc, 0, 0, 0);
    return rc;
}

