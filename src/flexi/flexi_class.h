//
// Created by slanska on 2017-02-12.
//

#ifndef FLEXILITE_FLEXI_CLASS_H
#define FLEXILITE_FLEXI_CLASS_H

#include "flexi_prop.h"
#include "../util/hash.h"

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


/*
 * Handle for Flexilite class definition
 */
struct flexi_class_def
{
    /*
     * Should be first field
     */
    sqlite3_vtab base;

    sqlite3_int64 iClassID;

    /*
     * Number of columns, i.e. items in property and column arrays
     */
    int nCols;

    /*
     * Actual length of pProps array (>= nCols)
     */
    int nPropColsAllocated;

    // Sorted array of mapping between property ID and column index
    //struct flexi_prop_col_map *pSortedProps;

    // Array of property metadata, by column index
    struct flexi_prop_def *pProps;

    char *zHash;
    sqlite3_int64 iNameID;
    short int bSystemClass;
    short int bAsTable;
    int xCtloMask;
    struct flexi_db_context *pCtx;

    flexi_metadata_ref aSpecProps[SPCL_PROP_COUNT];

    flexi_metadata_ref aFtsProps[FTS_PROP_COUNT];

    flexi_metadata_ref aRangeProps[RTREE_PROP_COUNT];

    Hash propMap;
};

int flexi_class_create(struct flexi_db_context *pCtx, const char *zClassName, const char *zClassDef, int bCreateVTable,
                       char **pzError);

void flexi_class_create_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

void flexi_class_alter_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

void flexi_class_drop_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

int flexi_class_rename(struct flexi_db_context *pCtx, sqlite3_int64 iOldClassID, const char *zNewName);

void flexi_class_rename_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

void flexi_change_object_class(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

void flexi_prop_to_obj_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);


/*
 * Internally used function to apply schema changes to the class that does not
 * have any data (so no data refactoring would be required)
 */
int flexi_alter_class_wo_data(struct flexi_db_context *pCtx, sqlite3_int64 lClassID,
                              const char *zNewClassDef, char **pzErr);

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
                      int bCreateVTable,
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

void flexi_obj_to_props_func(
        sqlite3_context *context,
        int argc,
        sqlite3_value **argv
);

void flexi_class_def_free(struct flexi_class_def *pClsDef);

#endif //FLEXILITE_FLEXI_CLASS_H
