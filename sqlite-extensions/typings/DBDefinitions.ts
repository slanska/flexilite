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
 and re-defined 'const' to handle TS-style enum declarations
 */

declare const enum SQLITE_OPEN_FLAGS
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
 Bit 50: Schema is not validated. Normally, this bit is set when object was referenced in other object
 but it was not defined in the schema

 */

declare const enum OBJECT_CONTROL_FLAGS
{
    CTLO_NONE = 0,
    CTLO_WEAK_OBJECT = 1 << 0,
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
    H_FTS = 1 << 32,
    I_FTS = 1 << 33,
    J_FTS = 1 << 34,
    A_RANGE = 1 << 37,
    B_RANGE = 1 << 38,
    C_RANGE = 1 << 39,
    D_RANGE = 1 << 40,
    E_RANGE = 1 << 41,
    F_RANGE = 1 << 42,
    G_RANGE = 1 << 43,
    H_RANGE = 1 << 44,
    I_RANGE = 1 << 45,
    J_RANGE = 1 << 46,
    NO_TRACK_CHANGES = 1 << 49,
    SCHEMA_NOT_ENFORCED = 1 << 50
};

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
declare const enum VALUE_CONTROL_FLAGS
{
    NONE = 0,
    INDEX = 1,
    REFERENCE = 2,
    REFERENCE_OWN = 4,
    REFERENCE_OWN_REVERSE = 6,
    REFERENCE_OWN_MUTUAL = 8,
    REFERENCE_DEPENDENT_MASTER = 10,
    REFERENCE_DEPENDENT_LINK = 12,
    REFERENCE_DEPENDENT_BOTH = 14,
    FULL_TEXT_INDEX = 16,
    RANGE_INDEX = 32,
    NO_TRACK_CHANGES = 64,
    UNIQUE_INDEX = 128
};

declare const enum Value_Control_Flags
{
    CTLV_NONE = 0,

    /*
     * Maximum four indexes (excluding unique indexes) are allowed per class
     */
    CTLV_INDEX = 1,
    CTLV_REFERENCE = 2,
    CTLV_REFERENCE_OWN = 4,
    CTLV_REFERENCE_OWN_REVERSE = 6,
    CTLV_REFERENCE_OWN_MUTUAL = 8,
    CTLV_REFERENCE_DEPENDENT_MASTER = 10,
    CTLV_REFERENCE_DEPENDENT_LINK = 12,
    CTLV_REFERENCE_DEPENDENT_BOTH = 14,
    CTLV_FULL_TEXT_INDEX = 16,
    CTLV_RANGE_INDEX = 32,
    CTLV_NO_TRACK_CHANGES = 64,

    /*
     * Though there is no limits on number of unique indexes, typically class will have 0 or 1 (rarely 2) unique index
     * in addition to object ID
     */
    CTLV_UNIQUE_INDEX = 128,

    /*
     * If property is indexed in RTREE, one of those flags would be set
     * X0 - means start value
     * X1 - means end value
     * X means both start and end values.
     */
    CTLV_RANGE_A0 = (1 << 8) + 0,
    CTLV_RANGE_A1 = (1 << 8) + 1,
    CTLV_RANGE_A = (1 << 8) + 2,
    CTLV_RANGE_B0 = (1 << 8) + 3,
    CTLV_RANGE_B1 = (1 << 8) + 4,
    CTLV_RANGE_B = (1 << 8) + 5,
    CTLV_RANGE_C0 = (1 << 8) + 6,
    CTLV_RANGE_C1 = (1 << 8) + 7,
    CTLV_RANGE_C = (1 << 8) + 8,
    CTLV_RANGE_D0 = (1 << 8) + 9,
    CTLV_RANGE_D1 = (1 << 8) + 10,
    CTLV_RANGE_D = (1 << 8) + 11
}
;

declare const enum FLEXILITE_LIMITS
{
    MaxOccurences = 1 << 31,
    MaxObjectID = 1 << 31
}
;

// Property types
declare const enum PROPERTY_TYPE
{
    PROP_TYPE_TEXT = 0,
    PROP_TYPE_INTEGER = 1,

    /*
     Stored as integer * 10000. Corresponds to Decimal(194). (The same format used by Visual Basic)
     */
    PROP_TYPE_DECIMAL = 2,

    /*
     8 byte float value
     */
    PROP_TYPE_NUMBER = 3,

    /*
     True or False
     */
    PROP_TYPE_BOOLEAN = 4,

    /*
     Boxed object or collection of objects.
     'boxed_object':
     referenced object stored as a part of master object. It does not have its own ID and can be accessed
     only via master object. Such object can have other boxed objects or boxed references but not LINKED_OBJECT references
     (since it does not have its own ID)
     */
    PROP_TYPE_OBJECT = 5,

    /*
     Selectable from fixed list of items
     */
    PROP_TYPE_ENUM = 6,

    /*
     Byte array (Buffer). Stored as byte 64 encoded value
     */
    PROP_TYPE_BINARY = 7,

    /*
     16 byte buffer. Stored as byte 64 encoded value (takes 22 bytes)
     */
    PROP_TYPE_UUID = 8,

    /*
     8 byte double corresponds to Julian day in SQLite
     */
    PROP_TYPE_DATETIME = 9,

    /*
     Presented as text but internally stored as name ID. Provides localization
     */
    PROP_TYPE_NAME = 10,

    /*
     Arbitrary JSON object not processed by Flexi
     */
    PROP_TYPE_JSON = 11,

    /*
     'linked_object':
     referenced object is stored in separate row has its own ID referenced via row in [.ref-values]
     and can be accessed independently from master object.
     This is most flexible option.
     */
    PROP_TYPE_LINK = 12,

    /*
     * Range types are tuples which combine 2 values - Start and End.
     * End value must be not less than Start.
     * In virtual table range types are presented as 2 columns: Start is named the same as range property, End has '^' symbol appended.
     * For example: Lifetime as date range property would be presented as [Lifetime] and [Lifetime_1] columns. If this
     * property has 'indexed' attribute, values would be stored in rtree table for fast lookup by range.
     * Unique indexes are not supported for range values
     */
    PROP_TYPE_NUMBER_RANGE = 13,
    PROP_TYPE_INTEGER_RANGE = 14,
    PROP_TYPE_DECIMAL_RANGE = 15,

    PROP_TYPE_DATE_RANGE = 16
}
;

/*
 subtype
 email
 password
 captcha
 timeonly
 textdocument
 image
 file
 dateonly
 ip4 address
 ip6 address

 */

/*
 Bit flags of roles that property plays in its class
 */
declare const enum PROPERTY_ROLE
{
    /*
     No special role
     */
    PROP_ROLE_NONE = 0x00,

    /*
     Object Name
     */
    PROP_ROLE_NAME = 0x0001,

    /*
     Property has object description
     */
    PROP_ROLE_DESCRIPTION = 0x0002,

    /*
     Property is alternative unique object ID. Once set, shouldn't be changed
     */
    PROP_ROLE_ID = 0x0004,

    /*
     Another alternative ID. Unlike ID, can be changed
     */
    PROP_ROLE_CODE = 0x0008,

    /*
     Alternative ID that allows duplicates
     */
    PROP_ROLE_NONUNIQUEID = 0x0010,

    /*
     Timestamp on when object was created
     */
    PROP_ROLE_CREATETIME = 0x0020,

    /*
     Timestamp on when object was last updated
     */
    PROP_ROLE_UPDATETIME = 0x0040,

    /*
     Auto generated UUID (16 byte blob)
     */
    PROP_ROLE_AUTOUUID = 0x0008,

    /*
     Auto generated short ID (7-16 characters)
     */
    PROP_ROLE_AUTOSHORTID = 0x0010
};

/*
 Level of priority for property to have fixed column assigned
 */
declare const enum COLUMN_ASSIGN_PRIORITY
{
    /*
     for indexed and ID/Code properties
     */
    COL_ASSIGN_REQUIRED = 2,

    /*
     For scalar properties
     */
    COL_ASSIGN_DESIRED = 1,

    /*
     Assignment is not set or not required
     */
    COL_ASSIGN_NOT_SET = 0
};
