//
// Created by slanska on 2017-02-16.
//

#ifndef FLEXILITE_FLEXI_PROP_C_H
#define FLEXILITE_FLEXI_PROP_C_H

#include <stdbool.h>
#include <sqlite3ext.h>

SQLITE_EXTENSION_INIT3

enum CHANGE_STATUS {
    CHNG_STATUS_NOT_MODIFIED = 0,
    CHNG_STATUS_ADDED = 1,
    CHNG_STATUS_MODIFIED = 2,
    CHNG_STATUS_DELETED = 3
};

typedef enum CHANGE_STATUS CHANGE_STATUS;

/*
 * Holds entity name and corresponding ID
 * Used for user-friendly way of specifying classes, properties, enums, names.
 * Holder of this struct is responsible for freeing name
 */
struct flexi_metadata_ref {
    const char *name;
    sqlite3_int64 id;

    CHANGE_STATUS eChngStatus;
};


typedef struct flexi_metadata_ref flexi_metadata_ref;

/*
 * Property definition object
 */
struct flexi_prop_def {
    struct flexi_db_context *pCtx;
    sqlite3_int64 lClassID;
    sqlite3_int64 iPropID;
    sqlite3_int64 iNameID;
    char *zName;
    char *zIndex;
    char *zSubType;
    int bNoTrackChanges;
    char *zEnumDef;
    char *zRefDef;
    char *zRenameTo;
    int bDrop;
    struct ReCompiled *pRegexCompiled;
    int type;
    char *zType;
    char *regex;
    double maxValue;
    double minValue;
    int maxLength;
    int minOccurences;
    int maxOccurences;
    sqlite3_value *defaultValue;
    short int xRole;
    char bIndexed;
    char bUnique;
    char bFullTextIndex;
    int xCtlv;

    flexi_metadata_ref enumDef;

    const char *zSrcJson;

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

    CHANGE_STATUS eChngStatus;
};

/// Parses JSON with property definition. pProp is expected to be zeroed and to have lClassID and pCtx initialized.
/// \param pProp
/// \param zPropDefJson
/// \return
int flexi_prop_def_parse(struct flexi_prop_def *pProp, const char *zPropName, const char *zPropDefJson);

/// Stringifies property definition to JSON
/// \param pProp
/// \param pzPropDefJson
/// \return
int flexi_prop_def_stringify(struct flexi_prop_def *pProp, char **pzPropDefJson);

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
int flexi_prop_def_get_changes_needed(struct flexi_prop_def *pOldDef, struct flexi_prop_def *pNewDef, int *piResult,
                                      const char **pzError);


/*
 * 'flexi' commands on properties
 */
void flexi_prop_create_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

void flexi_prop_alter_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

void flexi_prop_drop_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

void flexi_prop_rename_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

void flexi_prop_to_ref_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

void flexi_ref_to_prop_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

/*
 *
 */
void flexi_prop_def_free(struct flexi_prop_def const *prop);


#endif //FLEXILITE_FLEXI_PROP_C_H
