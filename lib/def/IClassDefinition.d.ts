/**
 * Created by slanska on 2016-03-27.
 */

/*
 Declarations for .classes Data
 */

/*
 Bit flags of roles that property plays in its class
 */
declare const enum PROPERTY_ROLE
{
    /*
     No special role
     */
    None = 0x00,

    /*
     Property has object title
     */
    Title = 0x01,

    /*
     Property has object description
     */
    Description = 0x02,

    /*
     Property is alternative unique object ID
     */
    Code = 0x04
}

declare const enum PROPERTY_TYPE
{
    text,
    integer,
    number,
    boolean,

    /*
     Reference to collection
     */
    reference,
    ENUM,
    binary,
    date,
    datetime,
    linked_value,
    time
}

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

 */

declare const enum UI_CONTROL_TYPE
{
    TEXT,
    COUNTER,
    SWITCH,
    SLIDER,
    combo,
    checkbox,
    radiobutton,
    segmented
}

interface IPropertyRulesSettings
{
    type:PROPERTY_TYPE;
    minOccurences?:number; // default: 0
    maxOccurences?:number; // default: 1
    maxLength?:number; // default: no limit
    minValue?:number; // default: no limit
    maxValue?:number; // default: no limit
    regex?:string;
}

declare const enum UI_COLUMN_TYPE
{

}


interface IPropertyUISettings
{
    icon?:string;

    control?:{
        type?:UI_CONTROL_TYPE;
        label?:string;
        /*
         Name ID
         */
        labelID?:number;
    }

    column?:{
        type?:UI_COLUMN_TYPE;
        label?:string;
    }
}



/*
 Class property metadata
 */
interface IClassProperty
{
    indexed?:boolean;
    unique?:boolean;
    role?: PROPERTY_ROLE;

    /*
     Name of this property before rename
     */
    $previousNameID?:number;

    ui?:IPropertyUISettings;
    rules:IPropertyRulesSettings;

    /*
     ID of referenced class
     */
    referenceTo?:number;

    /*
     Property name ID (in `referenceTo` class) used as reversed reference property for this one.
     */
    reversedPropertyID?:number;

    defaultValue?:any;
}

/*
 ClassID?:number;
 PropertyID?:number;
 PropertyName?:string;
 TrackChanges?:boolean;
 DefaultValue?:any;
 ctlo?:number;
 ctloMask?:number;
 DefaultDataType?:string;
 MinOccurences?:number;
 MaxOccurences?:number;
 Unique?:boolean;
 ColumnAssigned?:string;
 AutoValue?:string;
 MaxLength?:number;
 TempColumnAssigned?:number;
 ReferencedClassID?:number;
 ReversePropertyID?:number;
 ctlv?:number;
 Indexed?:boolean;
 ExtData?:any;
 ValidationRegex?:string;
 */

/*
 Structure of .classes.Data
 */
interface IClassDefinition
{
    /*
     Properties definition for view generation
     */
    properties:{[propID:number]:IClassProperty};
}
