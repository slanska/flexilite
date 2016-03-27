/**
 * Created by slanska on 2016-03-26.
 */

/*
Set of interfaces and constants to Flexilite's driver for SQLite database
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

declare const enum OBJECT_CONTROL_FLAGS
{
    NONE = 0,
    WEAK_OBJECT = 1,
    NO_TRACK_CHANGES = 1 << 49,
    SCHEMA_NOT_ENFORCED = 1 << 50
}

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
    NO_TRACK_CHANGES = 64
}


/*
 Mappings for tables in Flexilite database
 */

/*
.names
 */
interface IFlexiName
{
    NameID:number;
    Value:string;
    Data:any;
    PluralOf?:number;
    AliasOf?:number;
}

/*
 Map to the structure of .ref-values table
 */
interface IFlexiRefValue
{
    ObjectID:number;
    ClassID:number;
    PropertyID:number;
    PropIndex?:number;
    ctlv:VALUE_CONTROL_FLAGS;
    Value:any;
}

/*
 Mapping to .collections table
 */
interface IFlexiCollection
{
    /*
     Unique auto-incremented collection ID
     */
    CollectionID?:number;

    /*
     ID of collection name
     */
    NameID:number;

    /*
     Current base schema ID (latest version of base schema)
     */
    BaseSchemaNameID?:number;

    /*
     If true, defines collection as system: this one cannot be modified or deleted by end user
     */
    SystemCollection?:boolean;

    /*
     If true, indicates that view definition is outdated and needs to be regenerated
     */
    ViewOutdated?:boolean | number;

    ctloMask?:OBJECT_CONTROL_FLAGS;

    /*
     Optional maximum number of items in the collection
     */
    Capacity?:number;

    /*
     Optional property IDs for mapped columns
     */
    A?:number;
    B?:number;
    C?:number;
    D?:number;
    E?:number;
    F?:number;
    G?:number;
    H?:number;
    I?:number;
    J?:number;
}

/*
.access_rules
 */
interface  IFlexiAccessRule
{
    ItemID:number;
    ItemType:string;
    UserRoleID:number;
    Access:any;
}

/*
.change_log
 */
interface  IFlexiChangeLog
{
    ID:number;
    TimeStamp:number, // Julianday with fractional time, following SQLite format
    OldKey:any;
    OldValue:any;
    Key:any;
    Value:any;
    ChangedBy:any
}

/*
.schemas
 */
interface IFlexiSchema
{
    SchemaID:number;
    Variation:number;
    NameID:number;

    // JSON
    Data:any;

    Hash:string;
}

/*
.objects
 */
interface IFlexiObject
{
    ObjectID:number;
    CollectionID:number;
    SchemaID:number;
    ctlo:OBJECT_CONTROL_FLAGS;

    /*
    JSON text
     */
    Data: any;

    /*
    Field shortcuts (values extracted from Data)
     */
    A?:any;
    B?:any;
    C?:any;
    D?:any;
    E?:any;
    F?:any;
    G?:any;
    H?:any;
    I?:any;
    J?:any;
}


