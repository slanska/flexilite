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
#define WherePropertyID 1
#define WhereValuePropertyID 2
#define OrderByPropertyID 3
#define ObjectID 4
#define RefPropertyID 5
#define PropIndex 6

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
struct flexiGetData
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

/*
 * Returns:
 *  SQLITE_OK - if data was found and set to context result or search is over and NULL is set to context result
 *  SQLITE_NOTFOUND - data was not found, but there is possibility that linked object has data
 *  SQLERROR - any error occurred
 */
static int flexi_get_value(sqlite3 *db, sqlite3_int64 iPropID, sqlite3_int64 iObjectID, const char *zSchemaJson,
                           const char *zDataJson, struct flexiGetData *data,
                           sqlite3_context *context)
{
    // Get property definition from schema JSON.
    JsonParse x;          /* The parse */
    int parseResult = jsonParse(&x, context, zSchemaJson);
    if (parseResult != 0)
        // TODO process result
        return parseResult;

    JsonNode *propNode = jsonGetNode(&x, "$.properties.%d.map.jsonPath", (int) iPropID, context);
    if (propNode == NULL)
    {


    }
    //SQLITE_DONE;

    if (!propNode->u.zJContent || strlen(propNode->u.zJContent) == 0)
        // jsonPath not found. Try to use referenced property instead
    {
        // Reference property ID
        JsonNode *refPropNode = jsonGetNode(&x, "$.properties.%d.map.link.refPropID", (int) iPropID, context);
        if (refPropNode == NULL || refPropNode->u.zJContent == NULL)
            return SQLITE_NOTFOUND;

        // Linked object property ID
        JsonNode *valPropNode = jsonGetNode(&x, "$.properties.%d.map.link.valuePropID", (int) iPropID, context);
        if (valPropNode == NULL || valPropNode->u.zJContent == NULL)
            return SQLITE_NOTFOUND;

        int stmtIndex = 0;

        // Optional properties
        JsonNode *wherePropNode = NULL;
        JsonNode *whereValuePropNode = NULL;
        JsonNode *sortPropNode = NULL;
        JsonNode *descPropNode = NULL;
        // Property Index
        JsonNode *idxPropNode = jsonGetNode(&x, "$.properties.%d.map.link.propIndex", (int) iPropID, context);
        if (idxPropNode != NULL)
        {
            stmtIndex = 8;

        }
        else
        {

/*
 * 0 - first
 * 1 - sorted asc, no 'where'
 * 2 - last
 * 3 - sorted desc, no 'where'
 * 4 - where, no sort
 * 5 - where, sorted asc
 * 6 - where, last in list
 * 7 - where, sorted desc
 * 8 - by property index
 */



            // Where property ID
            wherePropNode = jsonGetNode(&x, "$.properties.%d.map.link.where.filterPropID", (int) iPropID,
                                        context);

            if (wherePropNode != NULL)
            {
                whereValuePropNode = jsonGetNode(&x, "$.properties.%d.map.link.where.valuePropID", (int) iPropID,
                                                 context);
                if (whereValuePropNode == NULL)
                {
                    // TODO Return NULL
                }
                stmtIndex |= 0x04;

            }
            // Sort property ID
            sortPropNode = jsonGetNode(&x, "$.properties.%d.map.link.sort.propID", (int) iPropID, context);
            if (sortPropNode != NULL)
            {
                stmtIndex |= 0x01;

            }
            // Desc property ID
            descPropNode = jsonGetNode(&x, "$.properties.%d.map.link.sort.desc", (int) iPropID, context);
            if (descPropNode != NULL)
                stmtIndex |= 0x02;
        }

        // Check if SQL statement has been already prepared
        if (data->statements[stmtIndex] == NULL)
        {
            const char *sql = sql_strings[stmtIndex];
            int result = sqlite3_prepare_v2(db,
                                            sql,
                                            (int) strlen(sql),
                                            &data->statements[stmtIndex],
                                            NULL);
        }

        sqlite3_stmt *stmt = data->statements[stmtIndex];
        sqlite3_reset(stmt);
        setSQLiteParam(stmt, WherePropertyID, wherePropNode);
        setSQLiteParam(stmt, WhereValuePropertyID, whereValuePropNode);
        setSQLiteParam(stmt, OrderByPropertyID, sortPropNode);
        setSQLiteParam(stmt, PropIndex, idxPropNode);
        sqlite3_bind_int(stmt, ObjectID, (int) iObjectID);
        setSQLiteParam(stmt, RefPropertyID, refPropNode);

        sqlite3_step(stmt);
    }

    // If not set, return NULL.

    // Check if data JSON has value on the path corresponding property definition

    // No direct data found. Check if schema has linked property definition

    // Build SQL to retrieve schema and data for linked property's data

    // Depending on configuration of linked property, there are few SQL variations possible to retrieve data from linked object
    // For sake of performance, these cases are handled by pre-compiled statements, which are kept in flexiGetData
    // structure (declared above)


    // Return result
    sqlite3_result_null(context);
    jsonParseReset(&x);
    return SQLITE_OK;
}

/*
 * Flexilite (https://github.com/slanska/flexilite) specific function.
 * Uses database structure defined in Flexilite database to dynamically process
 * defined data schema and returns actual value for the given property.
 * Process schemas in loop, via linked properties and stops when either value is found, or linked schemas are exhausted.
 * Expects 3 parameters:
 * property ID to retrieve
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

    struct flexiGetData *dataContext = (struct flexiGetData *) sqlite3_user_data(context);
    const sqlite3_int64 iPropID = sqlite3_value_int64(argv[0]);
    const sqlite3_int64 iObjectID = sqlite3_value_int64(argv[1]);
    const char *zSchemaJson = (const char *) sqlite3_value_text(argv[2]);
    const char *zDataJson = (const char *) sqlite3_value_text(argv[3]);

    while (1)
    {
        int result = flexi_get_value(db, iPropID, iObjectID, zSchemaJson, zDataJson, dataContext, context);
        if (result != 0)
            break;
    }
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

    struct flexiGetData *data = sqlite3_malloc(sizeof(struct flexiGetData));
    rc = sqlite3_create_function_v2(db, "flexi_get", 4, SQLITE_UTF8, data,
                                    sqlFlexiGetFunc, 0, 0, 0);
    return rc;
}

