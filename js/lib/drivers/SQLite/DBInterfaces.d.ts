/**
 * Created by slanska on 2016-03-26.
 */

///<reference path="../../../../src/typings/DBDefinitions.ts"/>
///<reference path="../../../typings/definitions.d.ts"/>

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
    NameID:number;
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
    NameID:number;

    /*
     Class name, by NameID
     */
    Name?:string;

    /*
     If true, defines collection as system: this one cannot be modified or deleted by end user
     */
    SystemClass?:boolean;

    ctloMask?:OBJECT_CONTROL_FLAGS;

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
    NameID:number;

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
    Data?:IClassPropertyDef;
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
interface IFlexiChangeLog
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
 .objects
 */
interface IFlexiObject
{
    ObjectID:number;
    ClassID:number;
    ctlo:OBJECT_CONTROL_FLAGS;

    /*
     Arbitrary JSON text
     */
    ExtData?:any;

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
    K?:any;
    L?:any;
    M?:any;
    N?:any;
    O?:any;
    P?:any;
}

declare type IFlexiClassPropDictionaryByName = {[propName:string]:IFlexiClassProperty};
declare type IFlexiClassPropDictionaryByID = {[propID:number]:IFlexiClassProperty};


