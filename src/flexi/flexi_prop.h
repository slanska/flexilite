//
// Created by slanska on 2017-02-16.
//

#ifndef FLEXILITE_FLEXI_PROP_C_H
#define FLEXILITE_FLEXI_PROP_C_H

#include <stdbool.h>
#include <sqlite3ext.h>
#include "flexi_db_ctx.h"
#include "flexi_class.h"
#include "class_ref_def.h"

SQLITE_EXTENSION_INIT3

/*
 * Forward declarations
 */
typedef struct flexi_ref_def flexi_ref_def;
typedef struct flexi_enum_def flexi_enum_def;

/*
 * Property definition object
 */
struct flexi_PropDef_t
{
    struct flexi_Context_t *pCtx;
    int nRefCount;
    sqlite3_int64 lClassID;
    sqlite3_int64 iPropID;

    // Attributes that need to be explicitly disposed
    char *zType;

    flexi_MetadataRef_t name;
    short int type;
    short int xRole;
    char bIndexed;
    char bUnique;
    char bFullTextIndex;
    bool bNoTrackChanges;

    /*
     * If true, marks this property as the one that potentially has invalid existing data and
     * a candidate to run validation process. Flag is cleared after validation scan is done and no
     * invalid data was found.
     * Invalid data = does not pass property rules (type, maxLength, regex etc.)
     */
    bool bValidate;

    /*
     * Existing property data need to be validated
     */
    bool bValidateDate;

    char *zIndex;
    char *zSubType;

    /*
     * For properties being altered/renamed - will have new property name
     */
    char *zRenameTo;

    char *regex;
    struct ReCompiled *pRegexCompiled;

    char *zEnumDef;
    flexi_enum_def *pEnumDef;

    char *zRefDef;
    Flexi_ClassRefDef_t *pRefDef;

    sqlite3_value *defaultValue;

    double maxValue;
    double minValue;

    flexi_MetadataRef_t enumDef;

    int maxLength;
    int minOccurences;

    int maxOccurences;
    int xCtlv;

    int xCtlvPlan;

    /*
     * 1-10: column is mapped to .range_data columns (1 = A0, 2 = A1, 3 = B0 and so on)
     * 0: not mapped
     */
    unsigned char cRangeColumn;

    /*
     * if not 0x00, mapped to a fixed column in [.objects] table (A-P)
     */
    unsigned char cColMapped;

    /*
     * 0 - no range column
     * 1 - low range bound
     * 2 - high range bound
     */
    unsigned char cRngBound;

    CHANGE_STATUS eChangeStatus;
};

/// @brief Allocates new class property structure and initializes it with class ID.
/// Other attributes need to be set in code or via flexi_prop_def_parse
/// @param lClassID
/// @return
struct flexi_PropDef_t *flexi_PropDef_new(sqlite3_int64 lClassID);

/// Parses JSON with property definition. pProp is expected to be zeroed and to have lClassID and pCtx initialized.
/// \param pProp
/// \param zPropDefJson
/// \return
int flexi_prop_def_parse(struct flexi_PropDef_t *pProp, const char *zPropName, const char *zPropDefJson);

/// Stringifies property definition to JSON
/// \param pProp
/// \param pzPropDefJson
/// \return
int flexi_prop_def_stringify(struct flexi_PropDef_t *pProp, char **pzPropDefJson);

/*
 * Transformation:
 * scalar -> reference: not allowed. 'property to reference' command should be used
 * regex added, removed or changed
 *
 * Shrinking:
 * reference -> scalar : not allowed. 'reference to property' command should be used
 *
 * text -> number -> integer -> boolean
 * text -> date
 * maxLength--
 * minValue++
 * maxValue--
 * minOccurrences++
 * maxOccurrences--
 *
 */
/// Compares 2 versions of the same property to detect if existing data needs to be validated and/or transformed
/// Result is set to piResult. 0 - no expanding or shrinking detected. 1 -
///
/// \param pOldDef
/// \param pNewDef
/// \param piResult
/// \param pzError
/// \return
int flexi_prop_def_get_changes_needed(struct flexi_PropDef_t *pOldDef, struct flexi_PropDef_t *pNewDef, int *piResult,
                                      const char **pzError);


/*
 * 'flexi' commands on properties
 */
int flexi_prop_create_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

int flexi_prop_alter_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

int flexi_prop_drop_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

int flexi_prop_rename_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

int flexi_prop_to_ref_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

int flexi_ref_to_prop_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

/*
 *
 */
void flexi_PropDef_free(struct flexi_PropDef_t *prop);

struct flexi_ref_def
{
    struct flexi_ClassRefDef base;
    flexi_MetadataRef_t reverseProperty;
    int autoFetchLimit;
    int autoFetchDepth;
    enum REF_PROP_ROLE rule;
};

void flexi_RefDef_free(Flexi_ClassRefDef_t *);

struct flexi_enum_def
{
};

void flexi_enum_def_free(flexi_enum_def *);

/*
 * Validates value against property rules
 * Returns SQLITE_OK if validation was passed
 * Otherwise, SQLITE_ERROR and sets context's error to a specific error message
 */
int flexi_PropDef_validateValue(struct flexi_PropDef_t *prop, flexi_ClassDef_t *pClassDef, sqlite3_value *value);

#endif //FLEXILITE_FLEXI_PROP_C_H
