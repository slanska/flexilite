//
// Created by slanska on 2016-03-13.
//

#include <string.h>
#include <printf.h>
#include "../../lib/sqlite/sqlite3ext.h"
#include "../misc/json1.h"

SQLITE_EXTENSION_INIT3

#include <string.h>

/*
 * Holds list of prepared statements to speed up 'flexi_get' function
 */
struct flexiGetData
{
    //
    const char *zSql1;
    const char *zSql2;
    const char *zSql3;
    const char *zSql4;
    const char *zSql5;
    const char *zSql6;
    const char *zSql7;
    const char *zSql8;
};

static void init_flexiGetData(sqlite3 *db, struct flexiGetData *data)
{

    // First item in list, by property index
    data->zSql1 = "select JSON_SET(o.Data, v.Data) as Data, s.Data as SchemaData,s.SchemaID as SchemaID, o.ObjectID as ObjectID"\
    " from [.ref-values] v join [.objects] o on v.ObjectID = o.ObjectID" \
"left outer join [.schemas] s on o.SchemaID = s.SchemaID"\
" where v.ObjectID = @ObjectID v.PropertyID = @RefPropertyID order by v.PropIndex asc limit 1";

    // Last item in list, by property index
    data->zSql2 = "select JSON_SET(o.Data, v.Data) as Data, s.Data as SchemaData,s.SchemaID as SchemaID, o.ObjectID as ObjectID"\
    " from [.ref-values] v join [.objects] o on v.ObjectID = o.ObjectID" \
"left outer join [.schemas] s on o.SchemaID = s.SchemaID"\
" where v.ObjectID = @ObjectID v.PropertyID = @RefPropertyID order by v.PropIndex desc limit 1";

    // First item in list, sorted and filtered
    data->zSql3 = "select * from ( select select JSON_SET(o.Data, v.Data) as Data, s.Data as SchemaData,s.SchemaID as SchemaID, o.ObjectID as ObjectID"\
    " from [.ref-values] v join [.objects] o on v.ObjectID = o.ObjectID" \
" left outer join [.schemas] s on o.SchemaID = s.SchemaID"\
" where v.ObjectID = @ObjectID v.PropertyID = @RefPropertyID) where flexi_get(@WherePropertyID, SchemaData, Data)"\
" order by flexi_get(@OrderByPropertyID, SchemaData, Data) asc limit 1";

    // Last item in list, sorted and filtered
    data->zSql4 = "select * from ( select JSON_SET(o.Data, v.Data) as Data, s.Data as SchemaData,s.SchemaID as SchemaID, o.ObjectID as ObjectID"\
    " from [.ref-values] v join [.objects] o on v.ObjectID = o.ObjectID" \
" left outer join [.schemas] s on o.SchemaID = s.SchemaID"\
" where v.ObjectID = @ObjectID v.PropertyID = @RefPropertyID) where flexi_get(@WherePropertyID, SchemaData, Data)"\
" order by flexi_get(@OrderByPropertyID, SchemaData, Data) desc limit 1";

    // First item in list, sorted
    data->zSql5 = "select * from ( select JSON_SET(o.Data, v.Data) as Data, s.Data as SchemaData,s.SchemaID as SchemaID, o.ObjectID as ObjectID"\
    " from [.ref-values] v join [.objects] o on v.ObjectID = o.ObjectID" \
" left outer join [.schemas] s on o.SchemaID = s.SchemaID"\
" where v.ObjectID = @ObjectID v.PropertyID = @RefPropertyID) "\
" order by flexi_get(@OrderByPropertyID, SchemaData, Data) asc limit 1";

// Last item in list, sorted
    data->zSql6 = "select * from ( select JSON_SET(o.Data, v.Data) as Data, s.Data as SchemaData,s.SchemaID as SchemaID, o.ObjectID as ObjectID"\
    " from [.ref-values] v join [.objects] o on v.ObjectID = o.ObjectID" \
" left outer join [.schemas] s on o.SchemaID = s.SchemaID"\
" where v.ObjectID = @ObjectID v.PropertyID = @RefPropertyID) "\
" order by flexi_get(@OrderByPropertyID, SchemaData, Data) desc limit 1";

    // First found item in list, filtered
    data->zSql7 = "select * from ( select JSON_SET(o.Data, v.Data) as Data, s.Data as SchemaData,s.SchemaID as SchemaID, o.ObjectID as ObjectID"\
    " from [.ref-values] v join [.objects] o on v.ObjectID = o.ObjectID" \
" left outer join [.schemas] s on o.SchemaID = s.SchemaID"\
" where v.ObjectID = @ObjectID v.PropertyID = @RefPropertyID) where flexi_get(@WherePropertyID, SchemaData, Data)"\
" limit 1";

    // Item in list, with certain property index
    data->zSql8 = "select JSON_SET(o.Data, v.Data) as Data, s.Data as SchemaData,s.SchemaID as SchemaID, o.ObjectID as ObjectID"\
    " from [.ref-values] v join [.objects] o on v.ObjectID = o.ObjectID" \
"left outer join [.schemas] s on o.SchemaID = s.SchemaID"\
" where v.ObjectID = @ObjectID v.PropertyID = @RefPropertyID and v.PropIndex = @PropertyIndex limit 1";
//    sqlite3_prepare_v2(db,
//    const char *zSql,       /* SQL statement, UTF-8 encoded */
//    int nByte,              /* Maximum length of zSql in bytes. */
//    sqlite3_stmt **ppStmt,  /* OUT: Statement handle */
//    const char **pzTail     /* OUT: Pointer to unused portion of zSql */);
}

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
 * Returns:
 *  SQLITE_OK - if data was found and set to context result or search is over and NULL is set to context result
 *  SQLITE_NOTFOUND - data was not found, but there is possibility that linked object has data
 *  SQLERROR - any error occured
 */
static int flexi_get_value(sqlite3 *db, sqlite3_int64 iPropID, const char *zSchemaJson,
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
 * 1 - sorted asc, no where
 * 2 - last
 * 3 - sorted desc, no where
 * 4 - where, no sort
 * 5 - where, sorted asc
 * 6 - where, last in list
 * 7 - where, sorted desc
 * 8 - by property index
 */

            // Where property ID
            JsonNode *wherePropNode = jsonGetNode(&x, "$.properties.%d.map.link.wherePropID", (int) iPropID, context);
            if (wherePropNode != NULL)
            {
                stmtIndex |= 0x04;

            }
            // Sort property ID
            JsonNode *sortPropNode = jsonGetNode(&x, "$.properties.%d.map.link.sortPropID", (int) iPropID, context);
            if (sortPropNode != NULL)
            {
                stmtIndex |= 0x01;

            }
            // Desc property ID
            JsonNode *descPropNode = jsonGetNode(&x, "$.properties.%d.map.link.sortDesc", (int) iPropID, context);
            if (descPropNode != NULL)
                stmtIndex |= 0x02;
        }


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
    if (argc != 3)
    {
        sqlite3_result_error(context, "Function flexi_get() expects 3 arguments", 1);
        return;
    }

    sqlite3 *db = sqlite3_context_db_handle(context);

    struct flexiGetData *dataContext = (struct flexiGetData *) sqlite3_user_data(context);
    const sqlite3_int64 iPropID = sqlite3_value_int64(argv[0]);
    const char *zSchemaJson = (const char *) sqlite3_value_text(argv[1]);
    const char *zDataJson = (const char *) sqlite3_value_text(argv[2]);

    while (1)
    {
        int result = flexi_get_value(db, iPropID, zSchemaJson, zDataJson, dataContext, context);
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
    rc = sqlite3_create_function_v2(db, "flexi_get", 3, SQLITE_UTF8, data,
                                    sqlFlexiGetFunc, 0, 0, 0);
    return rc;
}

