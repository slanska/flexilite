//
// Created by slanska on 2016-04-10.
//

/*
 * Commonly used constants and definitions to be used by library and external programs
 */

#ifndef SQLITE_EXTENSIONS_FLEXI_EAV_H
#define SQLITE_EXTENSIONS_FLEXI_EAV_H

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
#define CTLO_NONE                    0
#define CTLO_WEAK_OBJECT             1 << 0
#define CTLO_NO_TRACK_CHANGES        1 << 49
#define CTLO_SCHEMA_NOT_ENFORCED     1 << 50

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
#define     CTLV_NONE                        0
#define     CTLV_INDEX                       1
#define     CTLV_REFERENCE                   2
#define     CTLV_REFERENCE_OWN               4
#define     CTLV_REFERENCE_OWN_REVERSE       6
#define     CTLV_REFERENCE_OWN_MUTUAL        8
#define     CTLV_REFERENCE_DEPENDENT_MASTER  10
#define     CTLV_REFERENCE_DEPENDENT_LINK    12
#define     CTLV_REFERENCE_DEPENDENT_BOTH    14
#define     CTLV_FULL_TEXT_INDEX             16
#define     CTLV_RANGE_INDEX                 32
#define     CTLV_NO_TRACK_CHANGES            64
#define     CTLV_UNIQUE_INDEX                128

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


// Property types
// PROPERTY_TYPE

#define PROP_TYPE_TEXT  0
#define        PROP_TYPE_INTEGER  1

/*
 Stored as integer * 10000. Corresponds to Decimal(194). (The same format used by Visual Basic)
 */
#define        PROP_TYPE_DECIMAL  2

/*
 8 byte float value
 */
#define        PROP_TYPE_NUMBER  3

/*
 True or False
 */
#define        PROP_TYPE_BOOLEAN  4

/*
 Boxed object or collection of objects.
 'boxed_object':
 referenced object stored as a part of master object. It does not have its own ID and can be accessed
 only via master object. Such object can have other boxed objects or boxed references but not LINKED_OBJECT references
 (since it does not have its own ID)
 */
#define        PROP_TYPE_OBJECT  5

/*
 Selectable from fixed list of items
 */
#define        PROP_TYPE_ENUM  6

/*
 Byte array (Buffer). Stored as byte 64 encoded value
 */
#define        PROP_TYPE_BINARY  7

/*
 16 byte buffer. Stored as byte 64 encoded value (takes 22 bytes)
 */
#define        PROP_TYPE_UUID  8

/*
 8 byte double corresponds to Julian day in SQLite
 */
#define        PROP_TYPE_DATETIME  9

/*
 Presented as text but internally stored as name ID. Provides localization
 */
#define        PROP_TYPE_NAME  10

/*
 Arbitrary JSON object not processed by Flexi
 */
#define        PROP_TYPE_JSON  11

/*
 'linked_object':
 referenced object is stored in separate row has its own ID referenced via row in [.ref-values]
 and can be accessed independently from master object.
 This is most flexible option.
 */
#define        PROP_TYPE_LINK  12

#endif //SQLITE_EXTENSIONS_FLEXI_EAV_H
