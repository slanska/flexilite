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
var SQLITE_OPEN_FLAGS;
(function (SQLITE_OPEN_FLAGS) {
    SQLITE_OPEN_FLAGS[SQLITE_OPEN_FLAGS["SHARED_CACHE"] = 131072] = "SHARED_CACHE";
    SQLITE_OPEN_FLAGS[SQLITE_OPEN_FLAGS["WAL"] = 524288] = "WAL";
})(SQLITE_OPEN_FLAGS || (SQLITE_OPEN_FLAGS = {}));
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
var OBJECT_CONTROL_FLAGS;
(function (OBJECT_CONTROL_FLAGS) {
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["NONE"] = 0] = "NONE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["WEAK_OBJECT"] = 1] = "WEAK_OBJECT";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["A_UNIQUE"] = 2] = "A_UNIQUE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["B_UNIQUE"] = 4] = "B_UNIQUE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["C_UNIQUE"] = 8] = "C_UNIQUE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["D_UNIQUE"] = 16] = "D_UNIQUE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["E_UNIQUE"] = 32] = "E_UNIQUE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["F_UNIQUE"] = 64] = "F_UNIQUE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["G_UNIQUE"] = 128] = "G_UNIQUE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["H_UNIQUE"] = 256] = "H_UNIQUE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["I_UNIQUE"] = 512] = "I_UNIQUE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["J_UNIQUE"] = 1024] = "J_UNIQUE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["A_INDEXED"] = 8192] = "A_INDEXED";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["B_INDEXED"] = 16384] = "B_INDEXED";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["C_INDEXED"] = 32768] = "C_INDEXED";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["D_INDEXED"] = 65536] = "D_INDEXED";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["E_INDEXED"] = 131072] = "E_INDEXED";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["F_INDEXED"] = 262144] = "F_INDEXED";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["G_INDEXED"] = 524288] = "G_INDEXED";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["H_INDEXED"] = 1048576] = "H_INDEXED";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["I_INDEXED"] = 2097152] = "I_INDEXED";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["J_INDEXED"] = 4194304] = "J_INDEXED";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["A_FTS"] = 33554432] = "A_FTS";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["B_FTS"] = 67108864] = "B_FTS";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["C_FTS"] = 134217728] = "C_FTS";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["D_FTS"] = 268435456] = "D_FTS";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["E_FTS"] = 536870912] = "E_FTS";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["F_FTS"] = 1073741824] = "F_FTS";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["G_FTS"] = -2147483648] = "G_FTS";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["H_FTS"] = 1] = "H_FTS";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["I_FTS"] = 2] = "I_FTS";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["J_FTS"] = 4] = "J_FTS";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["A_RANGE"] = 32] = "A_RANGE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["B_RANGE"] = 64] = "B_RANGE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["C_RANGE"] = 128] = "C_RANGE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["D_RANGE"] = 256] = "D_RANGE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["E_RANGE"] = 512] = "E_RANGE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["F_RANGE"] = 1024] = "F_RANGE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["G_RANGE"] = 2048] = "G_RANGE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["H_RANGE"] = 4096] = "H_RANGE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["I_RANGE"] = 8192] = "I_RANGE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["J_RANGE"] = 16384] = "J_RANGE";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["NO_TRACK_CHANGES"] = 131072] = "NO_TRACK_CHANGES";
    OBJECT_CONTROL_FLAGS[OBJECT_CONTROL_FLAGS["SCHEMA_NOT_ENFORCED"] = 262144] = "SCHEMA_NOT_ENFORCED";
})(OBJECT_CONTROL_FLAGS || (OBJECT_CONTROL_FLAGS = {}));
;
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
var VALUE_CONTROL_FLAGS;
(function (VALUE_CONTROL_FLAGS) {
    VALUE_CONTROL_FLAGS[VALUE_CONTROL_FLAGS["NONE"] = 0] = "NONE";
    VALUE_CONTROL_FLAGS[VALUE_CONTROL_FLAGS["INDEX"] = 1] = "INDEX";
    VALUE_CONTROL_FLAGS[VALUE_CONTROL_FLAGS["REFERENCE"] = 2] = "REFERENCE";
    VALUE_CONTROL_FLAGS[VALUE_CONTROL_FLAGS["REFERENCE_OWN"] = 4] = "REFERENCE_OWN";
    VALUE_CONTROL_FLAGS[VALUE_CONTROL_FLAGS["REFERENCE_OWN_REVERSE"] = 6] = "REFERENCE_OWN_REVERSE";
    VALUE_CONTROL_FLAGS[VALUE_CONTROL_FLAGS["REFERENCE_OWN_MUTUAL"] = 8] = "REFERENCE_OWN_MUTUAL";
    VALUE_CONTROL_FLAGS[VALUE_CONTROL_FLAGS["REFERENCE_DEPENDENT_MASTER"] = 10] = "REFERENCE_DEPENDENT_MASTER";
    VALUE_CONTROL_FLAGS[VALUE_CONTROL_FLAGS["REFERENCE_DEPENDENT_LINK"] = 12] = "REFERENCE_DEPENDENT_LINK";
    VALUE_CONTROL_FLAGS[VALUE_CONTROL_FLAGS["REFERENCE_DEPENDENT_BOTH"] = 14] = "REFERENCE_DEPENDENT_BOTH";
    VALUE_CONTROL_FLAGS[VALUE_CONTROL_FLAGS["FULL_TEXT_INDEX"] = 16] = "FULL_TEXT_INDEX";
    VALUE_CONTROL_FLAGS[VALUE_CONTROL_FLAGS["RANGE_INDEX"] = 32] = "RANGE_INDEX";
    VALUE_CONTROL_FLAGS[VALUE_CONTROL_FLAGS["NO_TRACK_CHANGES"] = 64] = "NO_TRACK_CHANGES";
    VALUE_CONTROL_FLAGS[VALUE_CONTROL_FLAGS["UNIQUE_INDEX"] = 128] = "UNIQUE_INDEX";
})(VALUE_CONTROL_FLAGS || (VALUE_CONTROL_FLAGS = {}));
;
var Value_Control_Flags;
(function (Value_Control_Flags) {
    Value_Control_Flags[Value_Control_Flags["CTLV_NONE"] = 0] = "CTLV_NONE";
    /*
     * Maximum four indexes (excluding unique indexes) are allowed per class
     */
    Value_Control_Flags[Value_Control_Flags["CTLV_INDEX"] = 1] = "CTLV_INDEX";
    Value_Control_Flags[Value_Control_Flags["CTLV_REFERENCE"] = 2] = "CTLV_REFERENCE";
    Value_Control_Flags[Value_Control_Flags["CTLV_REFERENCE_OWN"] = 4] = "CTLV_REFERENCE_OWN";
    Value_Control_Flags[Value_Control_Flags["CTLV_REFERENCE_OWN_REVERSE"] = 6] = "CTLV_REFERENCE_OWN_REVERSE";
    Value_Control_Flags[Value_Control_Flags["CTLV_REFERENCE_OWN_MUTUAL"] = 8] = "CTLV_REFERENCE_OWN_MUTUAL";
    Value_Control_Flags[Value_Control_Flags["CTLV_REFERENCE_DEPENDENT_MASTER"] = 10] = "CTLV_REFERENCE_DEPENDENT_MASTER";
    Value_Control_Flags[Value_Control_Flags["CTLV_REFERENCE_DEPENDENT_LINK"] = 12] = "CTLV_REFERENCE_DEPENDENT_LINK";
    Value_Control_Flags[Value_Control_Flags["CTLV_REFERENCE_DEPENDENT_BOTH"] = 14] = "CTLV_REFERENCE_DEPENDENT_BOTH";
    Value_Control_Flags[Value_Control_Flags["CTLV_FULL_TEXT_INDEX"] = 16] = "CTLV_FULL_TEXT_INDEX";
    Value_Control_Flags[Value_Control_Flags["CTLV_RANGE_INDEX"] = 32] = "CTLV_RANGE_INDEX";
    Value_Control_Flags[Value_Control_Flags["CTLV_NO_TRACK_CHANGES"] = 64] = "CTLV_NO_TRACK_CHANGES";
    /*
     * Though there is no limits on number of unique indexes, typically class will have 0 or 1 (rarely 2) unique index
     * in addition to object ID
     */
    Value_Control_Flags[Value_Control_Flags["CTLV_UNIQUE_INDEX"] = 128] = "CTLV_UNIQUE_INDEX";
    /*
     * If property is indexed in RTREE, one of those flags would be set
     * X0 - means start value
     * X1 - means end value
     * X means both start and end values.
     */
    Value_Control_Flags[Value_Control_Flags["CTLV_RANGE_A0"] = 256] = "CTLV_RANGE_A0";
    Value_Control_Flags[Value_Control_Flags["CTLV_RANGE_A1"] = 257] = "CTLV_RANGE_A1";
    Value_Control_Flags[Value_Control_Flags["CTLV_RANGE_A"] = 258] = "CTLV_RANGE_A";
    Value_Control_Flags[Value_Control_Flags["CTLV_RANGE_B0"] = 259] = "CTLV_RANGE_B0";
    Value_Control_Flags[Value_Control_Flags["CTLV_RANGE_B1"] = 260] = "CTLV_RANGE_B1";
    Value_Control_Flags[Value_Control_Flags["CTLV_RANGE_B"] = 261] = "CTLV_RANGE_B";
    Value_Control_Flags[Value_Control_Flags["CTLV_RANGE_C0"] = 262] = "CTLV_RANGE_C0";
    Value_Control_Flags[Value_Control_Flags["CTLV_RANGE_C1"] = 263] = "CTLV_RANGE_C1";
    Value_Control_Flags[Value_Control_Flags["CTLV_RANGE_C"] = 264] = "CTLV_RANGE_C";
    Value_Control_Flags[Value_Control_Flags["CTLV_RANGE_D0"] = 265] = "CTLV_RANGE_D0";
    Value_Control_Flags[Value_Control_Flags["CTLV_RANGE_D1"] = 266] = "CTLV_RANGE_D1";
    Value_Control_Flags[Value_Control_Flags["CTLV_RANGE_D"] = 267] = "CTLV_RANGE_D";
})(Value_Control_Flags || (Value_Control_Flags = {}));
;
var FLEXILITE_LIMITS;
(function (FLEXILITE_LIMITS) {
    FLEXILITE_LIMITS[FLEXILITE_LIMITS["MaxOccurences"] = -2147483648] = "MaxOccurences";
    FLEXILITE_LIMITS[FLEXILITE_LIMITS["MaxObjectID"] = -2147483648] = "MaxObjectID";
})(FLEXILITE_LIMITS || (FLEXILITE_LIMITS = {}));
;
// Property types
var PROPERTY_TYPE;
(function (PROPERTY_TYPE) {
    PROPERTY_TYPE[PROPERTY_TYPE["PROP_TYPE_TEXT"] = 0] = "PROP_TYPE_TEXT";
    PROPERTY_TYPE[PROPERTY_TYPE["PROP_TYPE_INTEGER"] = 1] = "PROP_TYPE_INTEGER";
    /*
     Stored as integer * 10000. Corresponds to Decimal(194). (The same format used by Visual Basic)
     */
    PROPERTY_TYPE[PROPERTY_TYPE["PROP_TYPE_DECIMAL"] = 2] = "PROP_TYPE_DECIMAL";
    /*
     8 byte float value
     */
    PROPERTY_TYPE[PROPERTY_TYPE["PROP_TYPE_NUMBER"] = 3] = "PROP_TYPE_NUMBER";
    /*
     True or False
     */
    PROPERTY_TYPE[PROPERTY_TYPE["PROP_TYPE_BOOLEAN"] = 4] = "PROP_TYPE_BOOLEAN";
    /*
     Boxed object or collection of objects.
     'boxed_object':
     referenced object stored as a part of master object. It does not have its own ID and can be accessed
     only via master object. Such object can have other boxed objects or boxed references but not LINKED_OBJECT references
     (since it does not have its own ID)
     */
    PROPERTY_TYPE[PROPERTY_TYPE["PROP_TYPE_OBJECT"] = 5] = "PROP_TYPE_OBJECT";
    /*
     Selectable from fixed list of items
     */
    PROPERTY_TYPE[PROPERTY_TYPE["PROP_TYPE_ENUM"] = 6] = "PROP_TYPE_ENUM";
    /*
     Byte array (Buffer). Stored as byte 64 encoded value
     */
    PROPERTY_TYPE[PROPERTY_TYPE["PROP_TYPE_BINARY"] = 7] = "PROP_TYPE_BINARY";
    /*
     16 byte buffer. Stored as byte 64 encoded value (takes 22 bytes)
     */
    PROPERTY_TYPE[PROPERTY_TYPE["PROP_TYPE_UUID"] = 8] = "PROP_TYPE_UUID";
    /*
     8 byte double corresponds to Julian day in SQLite
     */
    PROPERTY_TYPE[PROPERTY_TYPE["PROP_TYPE_DATETIME"] = 9] = "PROP_TYPE_DATETIME";
    /*
     Presented as text but internally stored as name ID. Provides localization
     */
    PROPERTY_TYPE[PROPERTY_TYPE["PROP_TYPE_NAME"] = 10] = "PROP_TYPE_NAME";
    /*
     Arbitrary JSON object not processed by Flexi
     */
    PROPERTY_TYPE[PROPERTY_TYPE["PROP_TYPE_JSON"] = 11] = "PROP_TYPE_JSON";
    /*
     'linked_object':
     referenced object is stored in separate row has its own ID referenced via row in [.ref-values]
     and can be accessed independently from master object.
     This is most flexible option.
     */
    PROPERTY_TYPE[PROPERTY_TYPE["PROP_TYPE_LINK"] = 12] = "PROP_TYPE_LINK";
    /*
     * Range types are tuples which combine 2 values - Start and End.
     * End value must be not less than Start.
     * In virtual table range types are presented as 2 columns: Start is named the same as range property, End has '^' symbol appended.
     * For example: Lifetime as date range property would be presented as [Lifetime] and [Lifetime_1] columns. If this
     * property has 'indexed' attribute, values would be stored in rtree table for fast lookup by range.
     * Unique indexes are not supported for range values
     */
    PROPERTY_TYPE[PROPERTY_TYPE["PROP_TYPE_NUMBER_RANGE"] = 13] = "PROP_TYPE_NUMBER_RANGE";
    PROPERTY_TYPE[PROPERTY_TYPE["PROP_TYPE_INTEGER_RANGE"] = 14] = "PROP_TYPE_INTEGER_RANGE";
    PROPERTY_TYPE[PROPERTY_TYPE["PROP_TYPE_DECIMAL_RANGE"] = 15] = "PROP_TYPE_DECIMAL_RANGE";
    PROPERTY_TYPE[PROPERTY_TYPE["PROP_TYPE_DATE_RANGE"] = 16] = "PROP_TYPE_DATE_RANGE";
})(PROPERTY_TYPE || (PROPERTY_TYPE = {}));
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
var PROPERTY_ROLE;
(function (PROPERTY_ROLE) {
    /*
     No special role
     */
    PROPERTY_ROLE[PROPERTY_ROLE["PROP_ROLE_NONE"] = 0] = "PROP_ROLE_NONE";
    /*
     Object Name
     */
    PROPERTY_ROLE[PROPERTY_ROLE["PROP_ROLE_NAME"] = 1] = "PROP_ROLE_NAME";
    /*
     Property has object description
     */
    PROPERTY_ROLE[PROPERTY_ROLE["PROP_ROLE_DESCRIPTION"] = 2] = "PROP_ROLE_DESCRIPTION";
    /*
     Property is alternative unique object ID. Once set, shouldn't be changed
     */
    PROPERTY_ROLE[PROPERTY_ROLE["PROP_ROLE_ID"] = 4] = "PROP_ROLE_ID";
    /*
     Another alternative ID. Unlike ID, can be changed
     */
    PROPERTY_ROLE[PROPERTY_ROLE["PROP_ROLE_CODE"] = 8] = "PROP_ROLE_CODE";
    /*
     Alternative ID that allows duplicates
     */
    PROPERTY_ROLE[PROPERTY_ROLE["PROP_ROLE_NONUNIQUEID"] = 16] = "PROP_ROLE_NONUNIQUEID";
    /*
     Timestamp on when object was created
     */
    PROPERTY_ROLE[PROPERTY_ROLE["PROP_ROLE_CREATETIME"] = 32] = "PROP_ROLE_CREATETIME";
    /*
     Timestamp on when object was last updated
     */
    PROPERTY_ROLE[PROPERTY_ROLE["PROP_ROLE_UPDATETIME"] = 64] = "PROP_ROLE_UPDATETIME";
    /*
     Auto generated UUID (16 byte blob)
     */
    PROPERTY_ROLE[PROPERTY_ROLE["PROP_ROLE_AUTOUUID"] = 8] = "PROP_ROLE_AUTOUUID";
    /*
     Auto generated short ID (7-16 characters)
     */
    PROPERTY_ROLE[PROPERTY_ROLE["PROP_ROLE_AUTOSHORTID"] = 16] = "PROP_ROLE_AUTOSHORTID";
})(PROPERTY_ROLE || (PROPERTY_ROLE = {}));
;
//# sourceMappingURL=DBDefinitions.js.map