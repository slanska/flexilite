/**
 * Created by slanska on 2016-03-27.
 */

/*
 Definitions for .schemas Data JSON column
 */

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

interface IPropertyMapSettings
{
    jsonPath:string;

    /*
     For boolean properties, defined as items in array. For example:
     ['BoolProp1', 'BoolProp2', 'BoolProp3']. Presense of item in array means property `true` value.
     */
    itemInArray?:string;


}

interface ISchemaPropertyDefinition
{
    map:IPropertyMapSettings;
    ui?:IPropertyUISettings;
    rules:IPropertyRulesSettings;

    /*
     ID of referenced collection
     */
    referenceTo?:number;

    /*
     Property name ID (in `referenceTo` collection) used as reversed reference property for this one.
     */
    reversedPropertyID?:number;

    defaultValue?:any;

    /*
    Name of this property before rename
     */
    $previousName?:string;

}

/*
 Structure of Data fields in .schemas table
 */
interface ISchemaDefinition
{
    ui?:{
        defaultTemplates?:{
            form?:string;
            table?:string;
            item?:string;
            view?:string;
        };
    };
    properties:{[propertyID:number]:ISchemaPropertyDefinition};
}


