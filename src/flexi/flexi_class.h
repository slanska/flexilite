//
// Created by slanska on 2017-02-12.
//

#ifndef FLEXILITE_FLEXI_CLASS_H
#define FLEXILITE_FLEXI_CLASS_H

#include "../util/hash.h"
#include "flexi_db_ctx.h"
#include "../util/buffer.h"
#include "flexi_prop.h"
#include "class_ref_def.h"

/*
 * Column numbers and array indexes for class' special properties
 */
enum SPCL_PROP_IDX
{
    SPCL_PROP_UID = 0,
    SPCL_PROP_NAME = 1,
    SPCL_PROP_DESCRIPTION = 2,
    SPCL_PROP_CODE = 3,
    SPCL_PROP_NON_UNIQ_ID = 4,
    SPCL_PROP_CREATE_DATE = 5,
    SPCL_PROP_UPDATE_DATE = 6,
    SPCL_PROP_AUTO_UUID = 7,
    SPCL_PROP_AUTO_SHORT_ID = 8,
    SPCL_PROP_COUNT = SPCL_PROP_AUTO_SHORT_ID + 1
};

/*
 * Column numbers and array indexes for class' full text properties
 */
enum FTS_PROP_IDX
{
    FTS_PROP_X1 = 0,
    FTS_PROP_X2 = 1,
    FTS_PROP_X3 = 2,
    FTS_PROP_X4 = 3,
    FTS_PROP_X5 = 4,
    FTS_PROP_COUNT = FTS_PROP_X5 + 1
};

/*
 * Column numbers and array indexes for class' range index (rtree) properties
 */
enum RTREE_PROP_IDX
{
    RTREE_PROP_A0 = 0,
    RTREE_PROP_A1 = 1,
    RTREE_PROP_B0 = 2,
    RTREE_PROP_B1 = 3,
    RTREE_PROP_C0 = 4,
    RTREE_PROP_C1 = 5,
    RTREE_PROP_D0 = 6,
    RTREE_PROP_D1 = 7,
    RTREE_PROP_E0 = 8,
    RTREE_PROP_E1 = 9,
    RTREE_PROP_COUNT = RTREE_PROP_E1 + 1,
};

enum ALTER_CLASS_DATA_VALIDATION_MODE
{
    INVALID_DATA_ABORT = 0,
    INVALID_DATA_IGNORE = 1,
    INVALID_DATA_ERROR = 2
};

/*
 * Handle for Flexilite class definition
 */
struct flexi_class_def
{
    /*
     * Should be first field. Used for virtual table initialization
     */
    sqlite3_vtab base;

    sqlite3_int64 lClassID;

    // Array of property metadata, by column index
    struct flexi_prop_def *pProps;

    /*
     * Class definition hash
     *
     * TODO Needed?
     */
    char *zHash;

    /*
     * Class name definition
     */
    flexi_metadata_ref name;

    /*
     * This class is a system one, so that it cannot be removed
     */
    bool bSystemClass;

    /*
     * Class should have corresponding virtual table named after class. E.g. 'create virtual table Orders using flexi_data ();'
     */
    bool bAsTable;

    /*
     * Bitmask for various aspects of class storage (indexing etc.)
     */
    int xCtloMask;

    /*
     * Shortcut to Flexilite connection wide context
     */
    struct flexi_db_context *pCtx;

    /*
     * Special property definitions
     */
    flexi_metadata_ref aSpecProps[SPCL_PROP_COUNT];

    /*
     * Full text index property mapping
     */
    flexi_metadata_ref aFtsProps[FTS_PROP_COUNT];

    /*
     * Rtree index property mapping
     */
    flexi_metadata_ref aRangeProps[RTREE_PROP_COUNT];

    /*
     * Dictionary of properties by their names
     */
    Hash propMap;

    Buffer *aMixins;
};

int flexi_class_create(struct flexi_db_context *pCtx, const char *zClassName, const char *zClassDef, bool bCreateVTable,
                       const char **pzError);

int flexi_class_create_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

int flexi_class_alter_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

int flexi_class_drop_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

int flexi_class_rename(struct flexi_db_context *pCtx, sqlite3_int64 iOldClassID, const char *zNewName);

int flexi_class_rename_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

int flexi_change_object_class(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

int flexi_prop_to_obj_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);


/*
 * Internally used function to apply schema changes to the class that does not
 * have any data (so no data refactoring would be required)
 */
int _flexi_ClassDef_applyNewDef(struct flexi_db_context *pCtx, sqlite3_int64 lClassID, const char *zNewClassDef,
                                bool bCreateVTable, enum ALTER_CLASS_DATA_VALIDATION_MODE eValidateMode,
                                const char **pzErr);

///
/// \param pCtx
/// \param zClassName
/// \param zNewClassDefJson
/// \param bCreateVTable
/// \param pzError
/// \return
int flexi_class_alter(struct flexi_db_context *pCtx,
                      const char *zClassName,
                      const char *zNewClassDefJson,
                      enum ALTER_CLASS_DATA_VALIDATION_MODE eValidateMode,
                      bool bCreateVTable,
                      const char **pzError
);

///
/// \param pCtx
/// \param lClassID
/// \param softDelete
/// \return
int flexi_class_drop(struct flexi_db_context *pCtx, sqlite3_int64 lClassID, int softDelete, const char **pzError);

void flexi_props_to_obj_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

int flexi_obj_to_props_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

void flexi_class_def_free(struct flexi_class_def *pClsDef);

/*
 * Loads class definition from [.classes] and [flexi_prop] tables
 * into ppVTab (casted to flexi_vtab).
 * Used by Create and Connect methods
 */
int flexi_class_def_load(struct flexi_db_context *pCtx, sqlite3_int64 lClassID, struct flexi_class_def **pClassDef,
                         const char **pzErr);

/*
 * Generates SQL to create Flexilite virtual table from class definition
 */
int flexi_class_def_generate_vtable_sql(struct flexi_class_def *pClassDef, char **zSQL);

struct flexi_class_def *flexi_class_def_new(struct flexi_db_context *pCtx);

int flexi_class_def_parse(struct flexi_class_def *pClassDef, const char *zClassDefJson, const char **pzErr);

#endif //FLEXILITE_FLEXI_CLASS_H
