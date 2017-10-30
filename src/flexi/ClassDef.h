//
// Created by slanska on 2017-10-11.
//

#ifndef FLEXILITE_CLASSDEF_H
#define FLEXILITE_CLASSDEF_H

#include <memory>
#include <map>
#include <vector>
#include "PropertyDef.h"

#include "../project_defs.h"
#include "SymbolRef.h"

/*
 * Column numbers and array indexes for class' special properties
 */
enum class SPCL_PROP_IDX : int
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
enum class FTS_PROP_IDX : int
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
enum class RTREE_PROP_IDX : int
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

enum class ALTER_CLASS_DATA_VALIDATION_MODE
{
    INVALID_DATA_ABORT = 0,
    INVALID_DATA_IGNORE = 1,
    INVALID_DATA_ERROR = 2
};

/*
 * Definition for single Flexilite class
 */
class ClassDef
{
    sqlite3_int64 lClassID;

    std::vector<std::shared_ptr<PropertyDef>> properties = {};

    // Class definition hash. Needed?
    std::string &hash;

    /*
     * Class name
     */
    SymbolRef name;

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
     * Special property definitions
     */
    SymbolRef aSpecProps[(int) SPCL_PROP_IDX::SPCL_PROP_COUNT];

    /*
     * Full text index property mapping
     */
    SymbolRef aFtsProps[(int) FTS_PROP_IDX::FTS_PROP_COUNT];

    /*
     * Rtree index property mapping
     */
    SymbolRef aRangeProps[(int) RTREE_PROP_IDX::RTREE_PROP_COUNT];

    std::vector<std::shared_ptr<PropertyDef>> pProps{};

    std::vector<ClassRef> aMixins = {};

    /*
 * If true, any JSON is allowed to be inserted/updated
 */
    bool bAllowAnyProps;

    /*
 * If true, class is not completely resolved. CRUD operations are not allowed.
 */
    bool bUnresolved;
};


#endif //FLEXILITE_CLASSDEF_H
