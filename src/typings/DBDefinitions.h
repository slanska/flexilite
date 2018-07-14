//
// Created by slanska on 2016-04-30.
//

#ifndef DBDEFINITIONS_H
#define DBDEFINITIONS_H

#ifdef __cplusplus
extern "C" {
#endif

#define declare
#define const

/**
 * Created by slanska on 2016-04-30.
 */

/*
 Set of enum constants to Flexilite's driver for SQLite database tables

 This file is shared between TypeScript and C code of Flexilite. It is kind of hacky approach based on similarity of enum
 definitions in both TS and C. This file has integer constants only (bit flags and other constants),
 defined as enums, to be used in both SQLite extension
 library (compiled from C code) and portion of Flexilite written in TypeScript.

 Note: C requires semicolon after enum definition, TS/JS does not require it and will accept presence of ";" after closing "}"
 The only peculiarity if that when TS file is d.ts file (i.e. TS definition file), TS compiler will treat semicolon as error
 (probably, bug in TSC?).
 For that reason this file is created as a normal .ts file (not d.ts file). It is still OK to refer to this file as a regular d.ts file.

 From C prospective there is .h file (DBDefinitions.h) which includes this .ts file. H file also temporarily defines 'declare'
 and re-defines 'const' to handle TS-style enum declarations
 */

enum SQLITE_OPEN_FLAGS
{
    SHARED_CACHE = 0x00020000,
    WAL = 0x00080000
}
;

/*
 This is bit mask which regulates index storage.
 Bit 0: this object is a WEAK object and must be auto deleted after last reference to this object gets deleted.
 Bits 1-16: columns A-P should be indexed for fast lookup. These bits are checked by partial indexes
 Bits 17-32: columns A-P should be indexed for full text search
 Bits 33-48: columns A-P should be treated as range values and indexed for range (spatial search) search
 Bit 49: DON'T track changes
 */

enum OBJECT_CONTROL_FLAGS
{
    CTLO_NONE = 0ULL,
    CTLO_WEAK_OBJECT = 1L << 0,
    A_UNIQUE = 1 << 1,
    B_UNIQUE = 1 << 2,
    C_UNIQUE = 1 << 3,
    D_UNIQUE = 1 << 4,
    E_UNIQUE = 1 << 5,
    F_UNIQUE = 1 << 6,
    G_UNIQUE = 1 << 7,
    H_UNIQUE = 1 << 8,
    I_UNIQUE = 1 << 9,
    J_UNIQUE = 1 << 10,
    A_INDEXED = 1 << 13,
    B_INDEXED = 1 << 14,
    C_INDEXED = 1 << 15,
    D_INDEXED = 1 << 16,
    E_INDEXED = 1 << 17,
    F_INDEXED = 1 << 18,
    G_INDEXED = 1 << 19,
    H_INDEXED = 1 << 20,
    I_INDEXED = 1 << 21,
    J_INDEXED = 1 << 22,
    A_FTS = 1 << 25,
    B_FTS = 1 << 26,
    C_FTS = 1 << 27,
    D_FTS = 1 << 28,
    E_FTS = 1 << 29,
    F_FTS = 1 << 30,
    G_FTS = 1 << 31,
    H_FTS = 1UL << 32,
    I_FTS = 1L << 33,
    J_FTS = 1L << 34,
    A_RANGE = 1L << 37,
    B_RANGE = 1L << 38,
    C_RANGE = 1L << 39,
    D_RANGE = 1L << 40,
    E_RANGE = 1UL << 41,
    F_RANGE = 1UL << 42,
    G_RANGE = 1UL << 43,
    H_RANGE = 1UL << 44,
    I_RANGE = 1UL << 45,
    J_RANGE = 1UL << 46,
    NO_TRACK_CHANGES = 1UL << 49,
    SCHEMA_NOT_ENFORCED = 1 << 50,
    HAS_INVALID_DATA = 1 << 52
}
;

/*
 Bitmask for supported property types
 */
enum PROPERTY_TYPE
{
    /*
     Data type is determined on actual SQLite value type stored.
     TEXT -> PROP_TYPE_TEXT
     INTEGER -> PROP_TYPE_INTEGER
     FLOAT -> PROP_TYPE_NUMBER
     BLOB -> PROP_TYPE_BINARY
     NULL -> NULL
     */
            PROP_TYPE_AUTO = 0,

    /*
     'linked_object':
     referenced object is stored in separate row has its own ID referenced via row in [.ref-values]
     and can be accessed independently from master object.
     This is most flexible option.
     The same value as CTLV_REFERENCE
     */
            PROP_TYPE_REF = 1 << 0,

    PROP_TYPE_INTEGER = 1 << 1,

    /*
     Selectable from fixed list of items. Internally stored as INTEGER or TEXT
     */
            PROP_TYPE_ENUM = 1 << 2,

    /*
     Stored as integer * 10000. Corresponds to Decimal(19, 4). (The same format used by Visual Basic)
     */
            PROP_TYPE_DECIMAL = 1 << 3,

    /*
     Presented as text but internally stored as name ID (INTEGER). Provides localization
     */
            PROP_TYPE_NAME = 1 << 4,

    /*
     True or False, 1 or 0. Stored as INTEGER
     */
            PROP_TYPE_BOOLEAN = 1 << 5,

    /*
     8 byte float value. Stored as SQLite FLOAT
     */
            PROP_TYPE_NUMBER = 1 << 6,

    /*
     8 byte double corresponds to Julian day in SQLite
     */
            PROP_TYPE_DATETIME = 1 << 7,

    /*
     8 byte double corresponds to Julian day in SQLite
     */
            PROP_TYPE_TIMESPAN = 1 << 8,

    /*
     Byte array (Buffer).
     */
            PROP_TYPE_BINARY = 1 << 9,

    /*
     16 byte buffer.
     */
            PROP_TYPE_UUID = 1 << 10,

    PROP_TYPE_TEXT = 1 << 11,

    /*
     Arbitrary JSON object not processed by Flexi
     */
            PROP_TYPE_JSON = 1 << 12,

    PROP_TYPE_ANY = 1 << 13,

    PROP_TYPE_DATE = 0x7FFF
}
;

/*
 * If property is indexed in RTREE, one of those flags would be set
 * X0 - means start value
 * X1 - means end value
 * X means both start and end values.
 */
declare const enum Range_Column_Mapping
{
    RNG_MAP_RANGE_A0 = (1 << 9) + 0,
    RNG_MAP_RANGE_A1 = (1 << 9) + 1,
    RNG_MAP_RANGE_B0 = (1 << 9) + 2,
    RNG_MAP_RANGE_B1 = (1 << 9) + 3,
    RNG_MAP_RANGE_C0 = (1 << 9) + 4,
    RNG_MAP_RANGE_C1 = (1 << 9) + 5,
    RNG_MAP_RANGE_D0 = (1 << 9) + 6,
    RNG_MAP_RANGE_D1 = (1 << 9) + 7
}
;

declare const enum InvalidDataBehavior
{
    INV_DT_BEH_MARKCLASS,
    INV_DT_BEH_MARKOBJECTS,
    INV_DT_BEH_ERROR
}
;

/*
 ctlv is used for indexing and processing control. Possible values (the same as Values.ctlv):
 bit 0 - Index
 bits 1-5 - Type (including reference types)
 bit 6 - unique index
 bit 7 - no change tracking
 bit 8 - full text index
 bits 9-11 - rtree index
 bit 12 - bad data
 bit 13 - formula

 References:
 ==========
 2(3 as bit 0 is set) - regular ref
 4(5) - ref: A -> B. When A deleted, delete B
 6(7) - when B deleted, delete A
 8(9) - when A or B deleted, delete counterpart
 10(11) - cannot delete A until this reference exists
 12(13) - cannot delete B until this reference exists
 14(15) - cannot delete A nor B until this reference exist

 */
declare const enum Value_Control_Flags
{
    CTLV_NONE = 0,

    CTLV_INDEX = 1,

    /*
     Property types. Bits 1-5, all set(
     */
            CTLV_PROP_TYPE_MASK = 31 << 1,

    /*
     References
     */
            CTLV_REFERENCE = 2,
    CTLV_REFERENCE_OWN = 4,
    CTLV_REFERENCE_OWN_REVERSE = 6,
    CTLV_REFERENCE_OWN_MUTUAL = 8,
    CTLV_REFERENCE_DEPENDENT_MASTER = 10,
    CTLV_REFERENCE_DEPENDENT_LINK = 12,
    CTLV_REFERENCE_DEPENDENT_BOTH = 14,

    CTLV_REFERENCE_MASK = CTLV_INDEX | CTLV_REFERENCE | CTLV_REFERENCE_OWN | CTLV_REFERENCE_OWN_REVERSE |
                          CTLV_REFERENCE_OWN_MUTUAL | CTLV_REFERENCE_DEPENDENT_MASTER | CTLV_REFERENCE_DEPENDENT_LINK |
                          CTLV_REFERENCE_DEPENDENT_BOTH,

    /*
     * Though there is no limits on number of unique indexes, typically class will have 0 or 1 (rarely 2) unique index
     * in addition to object ID
     */
            CTLV_UNIQUE_INDEX = 1 << 6,

    CTLV_FULL_TEXT_INDEX = 1 << 8,

    CTLV_NO_TRACK_CHANGES = 1 << 7,

    /*
     * If property is indexed in RTREE, one of those flags would be set
     * X0 - means start value
     * X1 - means end value
     */
            CTLV_RANGE_A0 = 1 << 9,
    CTLV_RANGE_A1 = (1 << 9) + 1,
    CTLV_RANGE_B0 = (1 << 9) + 2,
    CTLV_RANGE_B1 = (1 << 9) + 3,
    CTLV_RANGE_C0 = (1 << 9) + 4,
    CTLV_RANGE_C1 = (1 << 9) + 5,
    CTLV_RANGE_D0 = (1 << 9) + 6,
    CTLV_RANGE_D1 = (1 << 9) + 7,

    CTLV_RANGE_MASK = CTLV_RANGE_A0 | CTLV_RANGE_A1 | CTLV_RANGE_B0 | CTLV_RANGE_B1 |
                      CTLV_RANGE_C0 | CTLV_RANGE_C1 | CTLV_RANGE_D0 | CTLV_RANGE_D1,

    CTLV_BAD_DATA = 1 << 12,

    CTLV_FORMULA = 1 << 13,

    CTLV_INDEX_MASK = CTLV_INDEX | CTLV_UNIQUE_INDEX | CTLV_FULL_TEXT_INDEX
}
;


/*
 subtype:
 =======
 email
 password
 captcha
 timeonly
 textdocument (html)
 image
 file name
 dateonly
 ip4 address
 ip6 address
 video
 audio
 link (url)
 */




#undef declare
#undef const

#ifdef __cplusplus
}
#endif

#endif