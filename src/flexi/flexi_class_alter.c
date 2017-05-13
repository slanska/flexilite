//
// Created by slanska on 2016-04-23.
//

/*
 * Implementation of class alteration
 */

#include "../project_defs.h"
#include "flexi_class.h"
#include "../util/List.h"

int flexi_buildInternalClassDefJSON(struct flexi_ClassDef_t *pClassDef, const char *zClassDef, char **pzOutput);

/*
 * Global mapping of type names between Flexilite and SQLite
 */
typedef struct
{
    const char *zFlexi_t;
    const char *zSqlite_t;
    int propType;
} FlexiTypesToSqliteTypeMap;

/*
 * Forward declarations
 */
typedef struct _ClassAlterContext_t _ClassAlterContext_t;

typedef struct _ClassAlterAction_t _ClassAlterAction_t;

/*
 * Pre- and post-action for class alter
 */
struct _ClassAlterAction_t
{
    /*
     * Pointer to next action in linked list
     */
    _ClassAlterAction_t *next;

    /*
     * Class or property reference
     */
    flexi_MetadataRef_t *ref;

    /*
     * Action function
     */
    int (*action)(_ClassAlterAction_t *self, _ClassAlterContext_t *pCtx);

    /*
     * Optional callback to dispose action's params
     */
    void (*disposeParams)(_ClassAlterAction_t *self);

    /*
     * Optional opaque params for the action
     */
    var params;
};

_ClassAlterAction_t *_ClassAlterAction_new(flexi_MetadataRef_t *ref,
                                           int (*action)(_ClassAlterAction_t *self, _ClassAlterContext_t *pCtx),
                                           void (*disposeParams)(_ClassAlterAction_t *self),
                                           var params)
{
    _ClassAlterAction_t *result = sqlite3_malloc(sizeof(_ClassAlterAction_t *));
    if (result)
    {
        result->action = action;
        result->disposeParams = disposeParams;
        result->params = params;
        result->ref = ref;
    }
    return result;
}

/*
 * Internally used composite for all parameters needed for class schema alteration
 */
struct _ClassAlterContext_t
{
    struct flexi_Context_t *pCtx;
    struct flexi_ClassDef_t *pNewClassDef;
    struct flexi_ClassDef_t *pExistingClassDef;

    /*
     * List of actions to be executed before scanning existing data
     */
    List_t preActions;

    /*
     * List of property level actions to be performed on every existing row during scanning
     */
    List_t postActions;

    /*
     * List of actions to be performed after scanning existing data
     */
    List_t propActions;

    enum ALTER_CLASS_DATA_VALIDATION_MODE eValidateMode;

    /*
     * Compiled statement to insert/update property definition
     */
    sqlite3_stmt *pUpsertPropDefStmt;

    /*
     * Result ot last executed SQLite operation
     */
    int nSqlResult;
};

static void
_ClassAlterContext_clear(_ClassAlterContext_t *self)
{
    List_clear(&self->propActions);
    List_clear(&self->preActions);
    List_clear(&self->postActions);

    if (self->pNewClassDef != NULL)
    {
        flexi_ClassDef_free(self->pNewClassDef);
    }

    sqlite3_finalize(self->pUpsertPropDefStmt);
}

/*
 * Map between Flexilite property types (in text representation) to
 * SQLite column types and internal Flexilite types (in int representation)
 */
const static FlexiTypesToSqliteTypeMap g_FlexiTypesToSqliteTypes[] = {
        {"text",      "TEXT",     PROP_TYPE_TEXT},
        {"integer",   "INTEGER",  PROP_TYPE_INTEGER},
        {"boolean",   "INTEGER",  PROP_TYPE_BOOLEAN},
        {"enum",      "TEXT",     PROP_TYPE_ENUM},
        {"number",    "FLOAT",    PROP_TYPE_NUMBER},
        {"datetime",  "FLOAT",    PROP_TYPE_DATETIME},
        {"uuid",      "BLOB",     PROP_TYPE_UUID},
        {"binary",    "BLOB",     PROP_TYPE_BINARY},
        {"name",      "TEXT",     PROP_TYPE_NAME},
        {"decimal",   "FLOAT",    PROP_TYPE_DECIMAL},
        {"json",      "JSON1",    PROP_TYPE_JSON},
        {"date",      "FLOAT",    PROP_TYPE_DATETIME},
        {"time",      "FLOAT",    PROP_TYPE_TIMESPAN},
        {"any",       "",         PROP_TYPE_ANY},
        {"text",      "NVARCHAR", PROP_TYPE_TEXT},
        {"text",      "NCHAR",    PROP_TYPE_TEXT},
        {"decimal",   "MONEY",    PROP_TYPE_DECIMAL},
        {"binary",    "IMAGE",    PROP_TYPE_BINARY},
        {"text",      "VARCHAR",  PROP_TYPE_TEXT},
        {"reference", "",         PROP_TYPE_REF},
        {"enum",      "",         PROP_TYPE_ENUM},
        {"name",      "",         PROP_TYPE_NAME},
        {NULL,        "TEXT",     PROP_TYPE_TEXT}
};

static const FlexiTypesToSqliteTypeMap *_findFlexiType(const char *t)
{
    int ii = 0;
    for (; ii < ARRAY_LEN(g_FlexiTypesToSqliteTypes); ii++)
    {
        if (g_FlexiTypesToSqliteTypes[ii].zFlexi_t && strcmp(g_FlexiTypesToSqliteTypes[ii].zFlexi_t, t) == 0)
            return &g_FlexiTypesToSqliteTypes[ii];
    }

    return &g_FlexiTypesToSqliteTypes[ARRAY_LEN(g_FlexiTypesToSqliteTypes) - 1];
}

/*
 * Allowed type transformations:
 * bool -> int -> decimal ->  number -> text -> name
 * date -> text
 * date -> number
 * number -> date
 * text -> date
 * int|number|text|date -> enum -> ref
 * int|number|text|date -> ref
 * text -> binary
 * binary -> text
 */

/*
 * Initializes enum property
 */
static int
_initEnumProp()
{
    // If property exists and defined as scalar prop, its current values will be treated
    // as uid/name/$id of enum item

    // Scan existing data, extract distinct values, find matching items in enum def.
    return 0;
}

/*
 * Initializes reference property
 */
static int
_initRefProp()
{
    // If property exists and defined as scalar prop, its current values will be treated as uid/$id/code/name
    // from the references class

    // Scan existing data and normalize it

    // Process reverse property
    return 0;
}

static int
_initNameProp()
{
    return 0;
}

/*
 * Mapping of upgrade and downgrade property types
 */
struct PropTypeTransitRule_t
{
    /*
     * Original property type
     */
    int type;

    /*
     * Can be upgraded without problem to these types (bitmask)
     */
    int yes;

    /*
     * May be OK to downgrade, but validation of existing data is needed
     */
    int maybe;

    bool rangeProp;

    bool fullTextProp;
};

static const struct PropTypeTransitRule_t g_propTypeTransitions[] =
        {
                {.type = PROP_TYPE_TEXT, .yes = PROP_TYPE_NAME | PROP_TYPE_REF | PROP_TYPE_BINARY | PROP_TYPE_JSON},
                {.type = PROP_TYPE_BOOLEAN, .yes = PROP_TYPE_INTEGER | PROP_TYPE_DECIMAL | PROP_TYPE_NUMBER |
                                                   PROP_TYPE_TEXT |
                                                   PROP_TYPE_ENUM},
                {.type = PROP_TYPE_INTEGER, .yes = PROP_TYPE_DECIMAL | PROP_TYPE_NUMBER | PROP_TYPE_TEXT |
                                                   PROP_TYPE_REF},
                {.type = PROP_TYPE_NUMBER, .yes = PROP_TYPE_TEXT, .maybe = PROP_TYPE_DECIMAL |
                                                                           PROP_TYPE_INTEGER},
                {.type = PROP_TYPE_ENUM, .yes = PROP_TYPE_TEXT | PROP_TYPE_NAME |
                                                PROP_TYPE_REF, .maybe = PROP_TYPE_INTEGER},
                {.type = PROP_TYPE_NAME, .yes = PROP_TYPE_TEXT | PROP_TYPE_REF, .maybe = PROP_TYPE_INTEGER |
                                                                                         PROP_TYPE_ENUM |
                                                                                         PROP_TYPE_NUMBER},
                {.type = PROP_TYPE_DECIMAL, .yes = PROP_TYPE_NUMBER | PROP_TYPE_TEXT, .maybe = PROP_TYPE_INTEGER},
                {.type = PROP_TYPE_DATE, .yes = PROP_TYPE_DATETIME | PROP_TYPE_TEXT},
                {.type = PROP_TYPE_DATETIME, .yes =PROP_TYPE_TEXT | PROP_TYPE_NUMBER | PROP_TYPE_DECIMAL},
                {.type = PROP_TYPE_BINARY, .yes = PROP_TYPE_TEXT, .maybe = PROP_TYPE_UUID},
                {.type = PROP_TYPE_TIMESPAN, .yes = PROP_TYPE_TEXT | PROP_TYPE_NUMBER, .maybe = PROP_TYPE_DECIMAL},
                {.type = PROP_TYPE_JSON, .yes = PROP_TYPE_TEXT | PROP_TYPE_REF, .maybe = PROP_TYPE_NUMBER},
                {.type = PROP_TYPE_UUID, .yes = PROP_TYPE_TEXT | PROP_TYPE_BINARY},
                {.type = PROP_TYPE_REF, .yes = PROP_TYPE_TEXT | PROP_TYPE_INTEGER | PROP_TYPE_DECIMAL},
                {.type = PROP_TYPE_ENUM, .yes = PROP_TYPE_TEXT | PROP_TYPE_INTEGER | PROP_TYPE_DECIMAL}
        };

static inline const struct PropTypeTransitRule_t *
_findPropTypeTransitRule(int propType)
{
    int i;
    const struct PropTypeTransitRule_t *result;
    result = &g_propTypeTransitions[0];
    for (i = 0; i < ARRAY_LEN(g_propTypeTransitions); i++, result++)
    {
        if (result->type == propType)
            return result;
    }

    return NULL;
}

/*
 * Compares 2 ref definitions. Returns
 */
static int
_compareRefDefs(struct flexi_ref_def *p1, struct flexi_ref_def *p2)
{
    return 0;
}

/*
 * Scans 2 sets of enum defs and checks if they are identical or not
 */
static int
_compareEnumDefs(const struct flexi_enum_def *p1, const struct flexi_enum_def *p2)
{
    return 0;
}

/*
 * Property action to check actual data type (if is compatible with new property definitions)
 */
static int _propAction_checkDataType(_ClassAlterAction_t *self, _ClassAlterContext_t *pCtx)
{
    return 0;
}

/*
 * At beginning of this function property can be in the following states:
 * ADDED, NON_MODIFIED (copied 'as-is' from existing class definition), MODIFIED or DELETED
 * Function:
 * a) checks property definition for consistency
 * b) determines it existing data should be validated
 * c) determines if property to be renamed
 * d) processes REF and ENUM types
 * e) tries its best to resolve class and property names by setting ID if possible. If resolving is impossible (class/property does not exist yet in the database)
 * it sets Unresolved flag in class def
 */
static void
_validatePropChange(const char *zPropName, int index, struct flexi_PropDef_t *p,
                    var pPropMap, _ClassAlterContext_t *alterCtx, bool *bStop)
{

    UNUSED_PARAM(pPropMap);
    UNUSED_PARAM(index);

#define CHECK_ERROR(condition, errorMessage) \
            if (condition) \
    { \
        flexi_Context_setError(alterCtx->pCtx, condition, errorMessage); \
        *bStop = true; \
        return; \
    }

    // Skip existing properties
    if (p->eChangeStatus == CHNG_STATUS_NOT_MODIFIED)
        return;

    // Check if class2 has the same property
    struct flexi_PropDef_t *pProp2;
    pProp2 = HashTable_get(&alterCtx->pExistingClassDef->propsByName, (DictionaryKey_t) {.pKey= zPropName});

    if (pProp2)
    {
        if (p->zRenameTo)
        {
            CHECK_ERROR (!db_validate_name(p->zRenameTo),
                         sqlite3_mprintf("Invalid new property name [%s] in class [%s]",
                                         p->zRenameTo, alterCtx->pExistingClassDef->name.name));
        }

        // Check if old and new types are compatible
        if (p->type != pProp2->type && p->type != PROP_TYPE_ANY)
        {
            const struct PropTypeTransitRule_t *transitRule = _findPropTypeTransitRule(p->type);

            if (transitRule)
            {
                if ((transitRule->yes & p->type) != 0)
                {
                    // Transition is OK
                }
                else
                {
                    if ((transitRule->maybe & p->type) != 0)
                    {
                        _ClassAlterAction_t *propAction = NULL;
                        propAction = _ClassAlterAction_new(&p->name, _propAction_checkDataType, NULL, p);
                        CHECK_ERROR(propAction == NULL, "No memory");
                        List_add(&alterCtx->propActions, propAction);
                    }
                    else transitRule = NULL;
                }
            }

            CHECK_ERROR (!transitRule,
                         sqlite3_mprintf(
                                 "Transition from type %s (%d) to type %s (%d) is not supported ([%s].[%s])",
                                 pProp2->zType, pProp2->type, p->zType, p->type, alterCtx->pNewClassDef->name.name,
                                 zPropName));
        }

        // For REF and ENUM property, check if refDef and enumDef, respectively, did not change
        if (p->type == pProp2->type)
        {
            switch (p->type)
            {
                case PROP_TYPE_REF:
                    //_compareRefDefs();
                    break;

                case PROP_TYPE_ENUM:
                    //                    _compareEnumDefs();
                    break;

                default:
                    break;
            }
        }
    }
    else
    {
        CHECK_ERROR (p->eChangeStatus == CHNG_STATUS_DELETED,
                     sqlite3_mprintf("Cannot drop non existing property '%s'", zPropName));

        CHECK_ERROR(p->zRenameTo,
                    sqlite3_mprintf("Cannot rename non existing property '%s'", zPropName));

        CHECK_ERROR(!db_validate_name(zPropName),
                    sqlite3_mprintf("Invalid property name [%s] in class [%s]",
                                    zPropName, alterCtx->pExistingClassDef->name.name));
    }

    // Validate property and initialize what's needed
    if (p->eChangeStatus != CHNG_STATUS_DELETED)
    {
        // Check consistency
        // type
        const FlexiTypesToSqliteTypeMap *typeMap = _findFlexiType(p->zType);
        CHECK_ERROR(!typeMap, sqlite3_mprintf("Unknown type \"%s\" for property [%s].[%s]", p->zType,
                                              alterCtx->pNewClassDef->name.name, zPropName));

        // minValue & maxValue
        CHECK_ERROR (p->minValue > p->maxValue,
                     sqlite3_mprintf("Property [%s].[%s]: minValue must be less than or equal maxValue",
                                     alterCtx->pNewClassDef->name.name,
                                     zPropName));

        // minOccurences & maxOccurences
        CHECK_ERROR(p->minOccurences < 0 || p->minOccurences > p->maxOccurences,
                    sqlite3_mprintf("Property [%s].[%s]: minOccurences must be between 0 and maxOccurrences",
                                    alterCtx->pNewClassDef->name.name,
                                    zPropName));

        // maxLength
        CHECK_ERROR(p->maxLength < 0,
                    sqlite3_mprintf("Property [%s].[%s]: maxLength must be 0 or positive integer",
                                    alterCtx->pNewClassDef->name.name,
                                    zPropName));

        // if ref, check refDef
        switch (typeMap->propType)
        {
            case PROP_TYPE_REF:
                _initRefProp();
                break;

            case PROP_TYPE_ENUM:
                _initEnumProp();
                break;

            case PROP_TYPE_NAME:
                _initNameProp();
                break;

            default:
                break;

        }

    }

#undef CHECK_ERROR
}

struct ValidateClassParams_t
{
    int nInvalidPropCount;
};

static void
_validateProp(const char *zPropName, int idx, struct flexi_PropDef_t *prop, var propMap,
              struct ValidateClassParams_t *params, bool *bStop)
{
    UNUSED_PARAM(zPropName);
    UNUSED_PARAM(idx);
    UNUSED_PARAM(propMap);
    if (prop->bValidate)
        // Already invalid. Nothing to do
        return;
}

/*
 * Checks if any property has 'bValidate' flag.
 * Scans existing objects and checks property data if they match property definition.
 * If so, flag 'bValidate' will be cleared.
 * zValidationMode defines how validation process will deal with invalid data:
 * ABORT (default) - processing will be aborted and SQLITE_CONSTRAINT will be returned
 * IGNORE - process will stop on first found invalid data and SQLITE_CONSTRAINT will be returned
 * MARK - process will scan all existing data and add IDs of invalid objects to the [.invalid_objects] table
 * SQLITE_CONSTRAINT will be returned.
 *
 * if no invalid data was found, SQLITE_OK will be returned
 */
static int
_validateClassData(_ClassAlterContext_t *alterCtx)
{
    int result;

    struct ValidateClassParams_t params = {};

    // Iterate

    HashTable_each(&alterCtx->pNewClassDef->propsByName, (void *) _validateProp, &params);


    return result;
}

/*
 * Iteratee function. Clones property definition to a new class def if it is not defined in the new class def
 */
static void
_copyExistingProp(const char *zPropName, int idx, struct flexi_PropDef_t *prop, var propMap,
                  _ClassAlterContext_t *alterCtx, bool *bStop)
{
    UNUSED_PARAM(bStop);
    UNUSED_PARAM(idx);
    UNUSED_PARAM(propMap);

    struct flexi_PropDef_t *pNewProp = HashTable_get(&alterCtx->pNewClassDef->propsByName,
                                                     (DictionaryKey_t) {.pKey = zPropName});
    if (!pNewProp)
    {
        HashTable_set(&alterCtx->pNewClassDef->propsByName, (DictionaryKey_t) {.pKey=zPropName}, prop);
        prop->eChangeStatus = CHNG_STATUS_NOT_MODIFIED;
        prop->nRefCount++;
    }
    else
        if (pNewProp->eChangeStatus != CHNG_STATUS_DELETED)
            pNewProp->eChangeStatus = CHNG_STATUS_MODIFIED;
}

/*
 * Determines if special properties have changed (or were never initialized)
 * Validates properties based on their role(s)
 * Ensures that indexing is set whenever needed
 */
static int
_processSpecialProps(_ClassAlterContext_t *alterCtx)
{
    int result;

    if (!flexi_metadata_ref_compare_n(&alterCtx->pNewClassDef->aSpecProps[0],
                                      &alterCtx->pExistingClassDef->aSpecProps[0],
                                      ARRAY_LEN(alterCtx->pNewClassDef->aSpecProps)))
    {
        // Special properties have changed (or, a special case, were not set in existing class def)
        // Need to reset existing properties and set new ones (indexing, not null etc.)

        //pNewClass->aSpecProps[SPCL_PROP_UID] - unique, required
        //pNewClass->aSpecProps[SPCL_PROP_CODE] - unique, required
        //        pNewClass->aSpecProps[SPCL_PROP_NAME] - unique, required
        //        SPCL_PROP_UID = 0,
        //        SPCL_PROP_NAME = 1,
        //        SPCL_PROP_DESCRIPTION = 2,
        //        SPCL_PROP_CODE = 3,
        //        SPCL_PROP_NON_UNIQ_ID = 4,
        //        SPCL_PROP_CREATE_DATE = 5,
        //        SPCL_PROP_UPDATE_DATE = 6,
        //        SPCL_PROP_AUTO_UUID = 7,
        //        SPCL_PROP_AUTO_SHORT_ID = 8,

    }


    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;
}

static void
_compPropByIdAndName(const char *zKey, u32 idx, struct flexi_PropDef_t *pProp, Hash *pPropMap,
                     flexi_MetadataRef_t *pRef,
                     bool *bStop)
{
    UNUSED_PARAM(zKey);
    UNUSED_PARAM(idx);
    UNUSED_PARAM(pPropMap);
    if (pProp->name.id == pRef->id || strcmp(pProp->name.name, pRef->name) == 0)
    {
        *bStop = true;
        return;
    }
}

/*
 * Finds property in class definition by property metadata (id or name)
 * TODO Use RB tree or Hash for search
 */
static bool
_findPropByMetadataRef(struct flexi_ClassDef_t *pClassDef, flexi_MetadataRef_t *pRef, struct flexi_PropDef_t **pProp)
{
    if (pRef->id != 0)
    {
        *pProp = HashTable_each(&pClassDef->propsByName, (void *) _compPropByIdAndName, pRef);
    }
    else
        *pProp = HashTable_get(&pClassDef->propsByName, (DictionaryKey_t) {.pKey=pRef->name});

    return *pProp != NULL;
}

static int
_processRangeProps(_ClassAlterContext_t *alterCtx)
{
    int result;

    if (!flexi_metadata_ref_compare_n(&alterCtx->pNewClassDef->aRangeProps[0],
                                      &alterCtx->pExistingClassDef->aRangeProps[0],
                                      ARRAY_LEN(alterCtx->pNewClassDef->aRangeProps)))
    {
        // validate
        /*
         * properties should be any
         */
        // old range data will be removed
    }

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;
}

static int
_processFtsProps(_ClassAlterContext_t *alterCtx)
{
    int result;

    if (!flexi_metadata_ref_compare_n(&alterCtx->pNewClassDef->aFtsProps[0], &alterCtx->pExistingClassDef->aFtsProps[0],
                                      ARRAY_LEN(alterCtx->pNewClassDef->aFtsProps)))
    {
    }

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;
}

static int
_processMixins(_ClassAlterContext_t *alterCtx)
{
    int result;

    /* Process mixins. If mixins are omitted in the new schema, existing definition of mixins will be used
 * if mixins are defined in both old and new schema, they will be compared for equality.
 * If not equal, data validation and processing needs to be performed
 *
 */
    if (!alterCtx->pNewClassDef->aMixins)
    {
        alterCtx->pNewClassDef->aMixins = alterCtx->pExistingClassDef->aMixins;
        if (alterCtx->pNewClassDef->aMixins != NULL)
            alterCtx->pNewClassDef->aMixins->nRefCount++;
    }
    else
    {
        // Try to initialize classes

    }


    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;
}

/*
 * Merges properties and other attributes in existing and new class definitions.
 * Validates property definition and marks them for removal/add/update/rename, if needed
 * Detects if existing class data needs to be validated/transformed, depending on property definition change
 * In case of any errors returns error code and sets pzErr to specific error message
 */
static int
_mergeClassSchemas(_ClassAlterContext_t *alterCtx)
{
    int result;

    // Copy existing properties if they are not defined in new schema
    // These properties will get eChangeStatus NONMODIFIED
    HashTable_each(&alterCtx->pExistingClassDef->propsByName, (void *) _copyExistingProp, alterCtx);
    if (alterCtx->pCtx->iLastErrorCode != SQLITE_OK)
        goto ONERROR;

    // Iterate through properties. Find props: to be renamed, to be deleted, to be updated, to be added
    HashTable_each(&alterCtx->pNewClassDef->propsByName, (void *) _validatePropChange, alterCtx);
    if (alterCtx->pCtx->iLastErrorCode != SQLITE_OK)
        goto ONERROR;

    // Process mixins
    CHECK_CALL(_processMixins(alterCtx));

    // Process special props
    CHECK_CALL(_processSpecialProps(alterCtx));

    // Process range props
    CHECK_CALL(_processRangeProps(alterCtx));

    // Process FTS props
    CHECK_CALL(_processFtsProps(alterCtx));

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:
    result = SQLITE_ERROR;

    EXIT:

    return result;
}

/*
 *
 */
static int
_createClassDefFromDefJSON(struct flexi_Context_t *pCtx, const char *zClassDefJson,
                           struct flexi_ClassDef_t **pClassDef, sqlite3_int64 lClassID, bool bAsTable)
{
    int result;
    const char *zErr = NULL;

    *pClassDef = flexi_class_def_new(pCtx);
    if (!*pClassDef)
    {
        result = SQLITE_NOMEM;
        goto ONERROR;
    }

    (*pClassDef)->lClassID = lClassID;
    (*pClassDef)->bAsTable = bAsTable;

    CHECK_CALL(flexi_ClassDef_parse(*pClassDef, zClassDefJson));

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    return result;
}

/*
 * Updates or inserts class property definition (via flexi_props view)
 */
static void
_upsertPropDef(const char *zPropName, const sqlite3_int64 index, struct flexi_PropDef_t *propDef,
               const Hash *propMap, _ClassAlterContext_t *alterCtx, bool *bStop)
{
    UNUSED_PARAM(zPropName);
    UNUSED_PARAM(propMap);
    UNUSED_PARAM(index);

    int result;

    CHECK_SQLITE(alterCtx->pCtx->db, sqlite3_reset(alterCtx->pUpsertPropDefStmt));
    sqlite3_bind_text(alterCtx->pUpsertPropDefStmt, 1, zPropName, -1, NULL);
    sqlite3_bind_int64(alterCtx->pUpsertPropDefStmt, 2, alterCtx->pNewClassDef->lClassID);
    sqlite3_bind_int(alterCtx->pUpsertPropDefStmt, 3, propDef->xCtlv);
    sqlite3_bind_int(alterCtx->pUpsertPropDefStmt, 4, propDef->xCtlvPlan);

    CHECK_STMT_STEP(alterCtx->pUpsertPropDefStmt, alterCtx->pCtx->db);
    if (result == SQLITE_DONE)
    {
        // Retrieve ID of property
        if (propDef->iPropID == 0)
        {
            if (alterCtx->pCtx->pStmts[STMT_SEL_PROP_ID_BY_NAME] == NULL)
            {
                CHECK_STMT_PREPARE(alterCtx->pCtx->db, "select ID from [.names_props] where "
                        "PropNameID = (select ID from [.names_props] where [Value] = :1 limit 1) limit 1;",
                                   &alterCtx->pCtx->pStmts[STMT_SEL_PROP_ID_BY_NAME]);
            }
            sqlite3_stmt *pGetPropIDStmt = alterCtx->pCtx->pStmts[STMT_SEL_PROP_ID_BY_NAME];
            CHECK_SQLITE(alterCtx->pCtx->db, sqlite3_reset(pGetPropIDStmt));
            sqlite3_bind_text(pGetPropIDStmt, 1, zPropName, -1, NULL);
            CHECK_STMT_STEP(pGetPropIDStmt, alterCtx->pCtx->db);
            propDef->iPropID = sqlite3_column_int64(pGetPropIDStmt, 0);
        }
    }
    result = SQLITE_OK;

    goto EXIT;

    ONERROR:
    *bStop = true;
    alterCtx->nSqlResult = result;
    flexi_Context_setError(alterCtx->pCtx, result, NULL);

    EXIT:

    printf("_upsertPropDef: %s. Result=%d\n",
           zPropName, result);

    return;
}

static void
_processAction(const char *zKey, const sqlite3_int64 index, _ClassAlterAction_t *actionDef,
               const List_t *actionList, _ClassAlterContext_t *alterCtx, bool *bStop)
{
    UNUSED_PARAM(zKey);
    UNUSED_PARAM(index);
    UNUSED_PARAM(actionList);

    if (actionDef->action)
        actionDef->action(actionDef, alterCtx);
}

static void
_fixupPropName(_ClassAlterContext_t *alterCtx, flexi_MetadataRef_t *pRef)
{
    if (pRef->id == 0 && pRef->name != NULL)
    {
        struct flexi_PropDef_t *prop = HashTable_get(&alterCtx->pNewClassDef->propsByName,
                                                     (DictionaryKey_t) {.pKey = pRef->name});
        if (prop != NULL)
        {
            pRef->id = prop->iPropID;
        }
    }
}

static void
_fixupPropNames(_ClassAlterContext_t *alterCtx)
{
    int i;
    flexi_MetadataRef_t *pRef;

    // FullText props
    for (i = 0; i < ARRAY_LEN(alterCtx->pNewClassDef->aFtsProps); i++)
    {
        _fixupPropName(alterCtx, &alterCtx->pNewClassDef->aFtsProps[i]);
    }

    // Special props
    for (i = 0; i < ARRAY_LEN(alterCtx->pNewClassDef->aSpecProps); i++)
    {
        _fixupPropName(alterCtx, &alterCtx->pNewClassDef->aSpecProps[i]);
    }

    // Range props
    for (i = 0; i < ARRAY_LEN(alterCtx->pNewClassDef->aRangeProps); i++)
    {
        _fixupPropName(alterCtx, &alterCtx->pNewClassDef->aRangeProps[i]);
    }

    // Mixins
    // TODO
}

/*
 * Physically saves class definition changes to the Flexilite database
 */
static int
_applyClassSchema(_ClassAlterContext_t *alterCtx, const char *zNewClassDef)
{
    int result;

    char *zInternalJSON = NULL;

    if (alterCtx->pUpsertPropDefStmt == NULL)
    {
        // TODO Use context statement
//        const char *zInsPropSQL = "insert or replace into [flexi_prop] (Property, ClassID, ctlv, ctlvPlan)"
//                " values (:1, :2, :3, :4);";
        const char *zInsPropSQL = "insert  into [flexi_prop] (Property, ClassID, ctlv, ctlvPlan)"
                " values (:1, :2, :3, :4);";
        CHECK_STMT_PREPARE(alterCtx->pCtx->db, zInsPropSQL, &alterCtx->pUpsertPropDefStmt);
    }

    // Pre-actions
    List_each(&alterCtx->preActions, (void *) _processAction, alterCtx);

    // Ensure properties exist and updated
    if (HashTable_each(&alterCtx->pNewClassDef->propsByName, (void *) _upsertPropDef, alterCtx) != NULL)
    {
        result = alterCtx->nSqlResult;
        CHECK_CALL(result);
    }

    // Use IDs of newly created properties
    _fixupPropNames(alterCtx);

    // Iterate through existing objects and run property level actions

    // Post-actions
    List_each(&alterCtx->postActions, (void *) _processAction, alterCtx);

    // Save class JSON definition
    if (alterCtx->pCtx->pStmts[STMT_UPDATE_CLS_DEF] == NULL)
    {
        CHECK_STMT_PREPARE(alterCtx->pCtx->db,
                           "update [.classes] set Data = :1 where ClassID = :2;",
                           &alterCtx->pCtx->pStmts[STMT_UPDATE_CLS_DEF]);
    }

    // Build internal class definition, using property IDs etc.
    flexi_buildInternalClassDefJSON(alterCtx->pNewClassDef, zNewClassDef, &zInternalJSON);

    printf("%s\n", zInternalJSON);

    sqlite3_stmt *pUpdClsStmt = alterCtx->pCtx->pStmts[STMT_UPDATE_CLS_DEF];
    CHECK_SQLITE(alterCtx->pCtx->db, sqlite3_reset(pUpdClsStmt));
    CHECK_SQLITE(alterCtx->pCtx->db, sqlite3_bind_text(pUpdClsStmt, 1, zInternalJSON, -1, NULL));
    CHECK_SQLITE(alterCtx->pCtx->db, sqlite3_bind_int64(pUpdClsStmt, 2, alterCtx->pNewClassDef->lClassID));

    CHECK_STMT_STEP(pUpdClsStmt, alterCtx->pCtx->db);

    result = SQLITE_OK;
    goto EXIT;

    ONERROR:

    EXIT:
    sqlite3_free(zInternalJSON);
    return result;
}

/*
 * Public API to alter class definition
 * Ensures that class already exists and calls _flexi_ClassDef_applyNewDef
 */
int
flexi_class_alter(struct flexi_Context_t *pCtx, const char *zClassName, const char *zNewClassDefJson,
                  enum ALTER_CLASS_DATA_VALIDATION_MODE eValidateMode, bool bCreateVTable)
{
    int result;

    // Check if class exists. If no - error
    // Check if class does not exist yet
    sqlite3_int64 lClassID;
    CHECK_CALL(flexi_Context_getClassIdByName(pCtx, zClassName, &lClassID));
    if (lClassID <= 0)
    {
        result = SQLITE_ERROR;
        flexi_Context_setError(pCtx, result, sqlite3_mprintf("Class [%s] is not found", zClassName));
        goto ONERROR;
    }

    // TODO temp
    printf("Altering class [%s]\n", zClassName);

    CHECK_CALL(_flexi_ClassDef_applyNewDef(pCtx, lClassID, zNewClassDefJson, bCreateVTable, eValidateMode));

    goto EXIT;

    ONERROR:
    if (pCtx->iLastErrorCode != SQLITE_OK)
        flexi_Context_setError(pCtx, result, NULL);

    EXIT:
    return result;
}

/*
 * Internal function to handle 'alter class' and 'create class' calls
 * Applies new definition to the class which does not yet have data
 * Loads class definition (if already exists) into temporary structure
 * Once new definition gets successfully applied, removes previous definition (if it was cached)
 * and sets new definition instead
 */
int _flexi_ClassDef_applyNewDef(struct flexi_Context_t *pCtx, sqlite3_int64 lClassID, const char *zNewClassDef,
                                bool bCreateVTable, enum ALTER_CLASS_DATA_VALIDATION_MODE eValidateMode)
{
    int result;

    assert(pCtx && pCtx->db);

    _ClassAlterContext_t alterCtx;
    memset(&alterCtx, 0, sizeof(alterCtx));

    alterCtx.pCtx = pCtx;
    List_init(&alterCtx.preActions, 0, NULL);
    List_init(&alterCtx.postActions, 0, NULL);
    List_init(&alterCtx.propActions, 0, NULL);
    alterCtx.eValidateMode = eValidateMode;

    // Load existing class def
    CHECK_CALL(flexi_ClassDef_load(pCtx, lClassID, &alterCtx.pExistingClassDef));

    // Parse new definition
    CHECK_CALL(_createClassDefFromDefJSON(pCtx, zNewClassDef, &alterCtx.pNewClassDef, lClassID, bCreateVTable));

    // Sets other class properties
    alterCtx.pNewClassDef->name.id = alterCtx.pExistingClassDef->name.id;
    alterCtx.pNewClassDef->name.name = sqlite3_mprintf("%s", alterCtx.pExistingClassDef->name.name);
    alterCtx.pNewClassDef->name.bOwnName = true;

    CHECK_CALL(_mergeClassSchemas(&alterCtx));

    CHECK_CALL(_applyClassSchema(&alterCtx, zNewClassDef));

    flexi_Context_addClassDef(pCtx, alterCtx.pNewClassDef);
    alterCtx.pNewClassDef = NULL;

    goto EXIT;

    ONERROR:
    if (alterCtx.pNewClassDef)
        flexi_ClassDef_free(alterCtx.pNewClassDef);
    flexi_Context_setError(pCtx, result, NULL);

    EXIT:

    _ClassAlterContext_clear(&alterCtx);

    return result;
}
