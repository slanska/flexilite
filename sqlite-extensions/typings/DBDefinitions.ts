/**
 * Created by slanska on 2016-04-30.
 */

/*
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
