//
// Created by slanska on 2016-04-10.
//

/*
 * Commonly used constants and definitions to be used by library and external programs
 */

#ifndef SQLITE_EXTENSIONS_FLEXI_EAV_H
#define SQLITE_EXTENSIONS_FLEXI_EAV_H

#include "../project_defs.h"

/*
 Set of interfaces and constants to Flexilite's driver for SQLite database tables
 */

/*
 This is bit mask which regulates index storage.
 Bit 0: this object is a WEAK object and must be auto deleted after last reference to this object gets deleted.
 Bits 1-16: columns A-P should be indexed for fast lookup. These bits are checked by partial indexes
 Bits 17-32: columns A-P should be indexed for full text search
 Bits 33-48: columns A-P should be treated as range values and indexed for range (spatial search) search
 Bit 49: DON'T track changes
 Bit 50: Schema is not validated. Normally, this bit is set when object was referenced in other object
 but it was not defined in the schema

 */
// ctlo flags

// OBJECT_CONTROL_FLAGS
//#define CTLO_NONE                    0
//#define CTLO_WEAK_OBJECT             1 << 0
//#define CTLO_NO_TRACK_CHANGES        1 << 49
//#define CTLO_SCHEMA_NOT_ENFORCED     1 << 50

/*
 ctlv is used for indexing and processing control. Possible values (the same as Values.ctlv):
 0 - Index
 1-3 - reference
 2(3 as bit 0 is set) - regular ref
 4(5) - ref: A -> B. When A deleted, delete B
 6(7) - when B deleted, delete A
 8(9) - when A or B deleted, delete counterpart
 10(11) - cannot delete A until this reference exists
 12(13) - cannot delete B until this reference exists
 14(15) - cannot delete A nor B until this reference exist

 16 - full text data
 32 - range data
 64 - DON'T track changes
 */
// ctlv flags

//VALUE_CONTROL_FLAGS
//enum
//{
//    CTLV_NONE = 0,
//
//    /*
//     * Maximum four indexes (excluding unique indexes) are allowed per class
//     */
//            CTLV_INDEX = 1,
//    CTLV_REFERENCE = 2,
//    CTLV_REFERENCE_OWN = 4,
//    CTLV_REFERENCE_OWN_REVERSE = 6,
//    CTLV_REFERENCE_OWN_MUTUAL = 8,
//    CTLV_REFERENCE_DEPENDENT_MASTER = 10,
//    CTLV_REFERENCE_DEPENDENT_LINK = 12,
//    CTLV_REFERENCE_DEPENDENT_BOTH = 14,
//    CTLV_FULL_TEXT_INDEX = 16,
//    CTLV_RANGE_INDEX = 32,
//    CTLV_NO_TRACK_CHANGES = 64,
//
//    /*
//     * Though there is no limits on number of unique indexes, typically class will have 0 or 1 (rarely 2) unique index
//     * in addition to object ID
//     */
//            CTLV_UNIQUE_INDEX = 128,
//
//    /*
//     * If property is indexed in RTREE, one of those flags would be set
//     * X0 - means start value
//     * X1 - means end value
//     * X means both start and end values.
//     */
//            CTLV_RANGE_A0 = (1 << 8) + 0,
//    CTLV_RANGE_A1 = (1 << 8) + 1,
//    CTLV_RANGE_A = (1 << 8) + 2,
//    CTLV_RANGE_B0 = (1 << 8) + 3,
//    CTLV_RANGE_B1 = (1 << 8) + 4,
//    CTLV_RANGE_B = (1 << 8) + 5,
//    CTLV_RANGE_C0 = (1 << 8) + 6,
//    CTLV_RANGE_C1 = (1 << 8) + 7,
//    CTLV_RANGE_C = (1 << 8) + 8,
//    CTLV_RANGE_D0 = (1 << 8) + 9,
//    CTLV_RANGE_D1 = (1 << 8) + 10,
//    CTLV_RANGE_D = (1 << 8) + 11
//} Value_Control_Flags;

// Property roles
/*
 Bit flags of roles that property plays in its class
 */
// PROPERTY_ROLE
/*
 No special role
 */
#define            PROP_ROLE_NONE  0x00

/*
 Property has object title
 */
#define            PROP_ROLE_TITLE  0x01

/*
 Property has object description
 */
#define            PROP_ROLE_DESCRIPTION  0x02

/*
 Property is alternative unique object ID. Once set shouldn't be changed
 */
#define    PROP_ROLE_ID  0x04
#define    PROP_ROLE_IDPART1  0x04
#define    PROP_ROLE_IDPART2  0x05
#define    PROP_ROLE_IDPART3  0x06
#define    PROP_ROLE_IDPART4  0x07

/*
 Another alternative ID. Unlike ID can be changed
 */
#define            PROP_ROLE_NAME  0x08


//// Property types
//// PROPERTY_TYPE
//enum
//{
//    PROP_TYPE_TEXT = 0,
//    PROP_TYPE_INTEGER = 1,
//
///*
// Stored as integer * 10000. Corresponds to Decimal(194). (The same format used by Visual Basic)
// */
//            PROP_TYPE_DECIMAL = 2,
//
///*
// 8 byte float value
// */
//            PROP_TYPE_NUMBER = 3,
//
///*
// True or False
// */
//            PROP_TYPE_BOOLEAN = 4,
//
///*
// Boxed object or collection of objects.
// 'boxed_object':
// referenced object stored as a part of master object. It does not have its own ID and can be accessed
// only via master object. Such object can have other boxed objects or boxed references but not LINKED_OBJECT references
// (since it does not have its own ID)
// */
//            PROP_TYPE_OBJECT = 5,
//
///*
// Selectable from fixed list of items
// */
//            PROP_TYPE_ENUM = 6,
//
///*
// Byte array (Buffer). Stored as byte 64 encoded value
// */
//            PROP_TYPE_BINARY = 7,
//
///*
// 16 byte buffer. Stored as byte 64 encoded value (takes 22 bytes)
// */
//            PROP_TYPE_UUID = 8,
//
///*
// 8 byte double corresponds to Julian day in SQLite
// */
//            PROP_TYPE_DATETIME = 9,
//
///*
// Presented as text but internally stored as name ID. Provides localization
// */
//            PROP_TYPE_NAME = 10,
//
///*
// Arbitrary JSON object not processed by Flexi
// */
//            PROP_TYPE_JSON = 11,
//
///*
// 'linked_object':
// referenced object is stored in separate row has its own ID referenced via row in [.ref-values]
// and can be accessed independently from master object.
// This is most flexible option.
// */
//            PROP_TYPE_LINK = 12,
//
///*
// * Range types are tuples which combine 2 values - Start and End.
// * End value must be not less than Start.
// * In virtual table range types are presented as 2 columns: Start is named the same as range property, End has '^' symbol appended.
// * For example: Lifetime as date range property would be presented as [Lifetime] and [Lifetime_1] columns. If this
// * property has 'indexed' attribute, values would be stored in rtree table for fast lookup by range.
// * Unique indexes are not supported for range values
// */
//            PROP_TYPE_NUMBER_RANGE = 13,
//    PROP_TYPE_INTEGER_RANGE = 14,
//    PROP_TYPE_DECIMAL_RANGE = 15,
//
//    PROP_TYPE_DATE_RANGE = 16
//} PropertyDataType;

#endif //SQLITE_EXTENSIONS_FLEXI_EAV_H
