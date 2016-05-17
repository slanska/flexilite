/**
 * Created by slanska on 2016-03-26.
 */

///<reference path="../../../typings/lib.d.ts"/>

/*
 Set of interfaces and constants to Flexilite's driver for SQLite database tables
 */

/*
 Mappings for tables in Flexilite database
 */

/*
 .names
 */
interface IFlexiName
{
    NameID:NameID;
    Value:string;
    Data:any; // TODO Finalize structure. Multi language support?
    PluralOf?:number;
    AliasOf?:number;
}

/*
 Map to the structure of .ref-values table
 */
interface IFlexiRefValue
{
    ObjectID:number;
    PropertyID:number;
    PropIndex:number;
    ctlv:Value_Control_Flags;

    /*
     Scalar value linked object ID
     */
    Value?:any;

    /*
     Optional extra data
     */
    ExtData?:any;
}

/*
 Mapping to .collections table
 */
interface IFlexiClass
{
    /*
     Unique auto-incremented collection ID
     */
    ClassID?:number;

    /*
     ID of collection name
     */
    NameID:NameID;

    /*
     Class name, by NameID
     */
    Name?:string;

    /*
     If true, defines collection as system: this one cannot be modified or deleted by end user
     */
    SystemClass?:boolean;

    ctloMask?:OBJECT_CONTROL_FLAGS;

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

    // [Data] signature for the fast lookup
    Hash?:string;

    Data:IClassDefinition;

    AccessRules?:any;

    Properties?:IFlexiClassProperty[];
}

/*
 Mapping to [.class_properties] table and [vw_class_properties] view
 */
interface IFlexiClassProperty
{
    PropertyID?:number;
    ClassID:number;
    NameID:NameID;

    /*
     Computed property. Taken from [.names] based on NameID
     */
    Name?:string;

    /*
     Current settings
     */
    ctlv:Value_Control_Flags;

    /*
     Suggested but not yet applied settings: indexing etc.
     */
    ctlvPlan?:Value_Control_Flags;

    /*
     JSON text. Computed property taken from [.classes]
     */
    Data?:IClassProperty;
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
    TimeStamp:number, // Julian day with fractional time (SQLite format)
    OldKey:any;
    OldValue:any;
    Key:any;
    Value:any;
    ChangedBy:any
}

/*
 .schemas
 */
// interface IFlexiSchema
// {
//     // Auto increment primary key
//     SchemaID?:number;
//
//     // Class name ID
//     NameID:NameID;
//
//     // Data signature for the fast access
//     Hash:string;
//
//     // JSON text
//     Data:ISchemaDefinition;
// }

/*
 .objects
 */
interface IFlexiObject
{
    ObjectID:number;
    ClassID:number;
    SchemaID:number;
    ctlo:OBJECT_CONTROL_FLAGS;

    /*
     Arbitrary JSON text
     */
    Data?:any;

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

declare type IFlexiClassPropDictionaryByName = {[propName:string]:IFlexiClassProperty};
declare type IFlexiClassPropDictionaryByID = {[propID:number]:IFlexiClassProperty};


