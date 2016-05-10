/**
 * Created by slanska on 2016-03-27.
 */

/*
 Declarations for .classes Data
 */

///<reference path="../../sqlite-extensions/typings/DBDefinitions.ts"/>

declare type NameId = number;
declare type NameIdOrString = NameId | string;


declare const enum UI_CONTROL_TYPE
{
    TEXT = 0,
    COUNTER = 1,
    SWITCH = 2,
    SLIDER = 3,
    COMBO = 4,
    CHECKBOX = 5,
    RADIOBUTTON = 6,
    SEGMENTED = 7

    // TODO More types?
}

interface IPropertyRulesSettings
{
    type:PROPERTY_TYPE;
    minOccurences?:number; // default: 0
    maxOccurences?:number; // default: 1
    maxLength?:number; // default: no limit
    minValue?:number; // default: no limit
    maxValue?:number; // default: no limit
    regex?:string; // Value casted to text and then tested for matching regex
}

declare const enum UI_COLUMN_TYPE
{
// TODO Table columns
}

interface IPropertyUISettings
{
    icon?:string;

    control?:{
        type?:UI_CONTROL_TYPE;
        label?:NameIdOrString;
    }

    column?:{
        type?:UI_COLUMN_TYPE;
        label?:NameIdOrString;
    }
}

interface IEnumPropertyDefinition
{
    /*
     Hard coded list of items to select from. Either Text or TextID are required to serve
     */
    items:[{
        ID:string | number,
        Text?:string,
        TextID?:NameId
    }]
}

interface IObjectPropertyDefinition
{
    classID?:number;
    /*
     or
     */
    $className?:string;

    /*
     if prop.rules.type = PROP_TYPE_OBJECT, this attribute helps to determine actual class ID of boxed/nested object.
     This feature allows to dynamically extend objects with different classes. If this attribute is set,
     classID attribute is not used. Also, this attribute is used to prepare list of class IDs available
     for selection when initializing new master object.
     */
    resolve?:{
        /*
         ID of property in the same object that is used as a source value to determine actual class type of boxed object
         */
        selectorPropID?:number;

        /*
         List of values: exactValue, class ID and optional regex. If value from selector property is equal to exactValue or
         matches regex, corresponding class ID is selected. Matching is applied lineary, starting from 1st item in rules array.
         Also, list of class IDs is used to build list of available classes when user creates a new object and needs
         to select specific class. In this case, 'exactValue' attribute is used to populate selectorPropID if specified.
         If it is not specified, selector value will be set to selected class ID
         */
        rules?:[{ classID:number, exactValue?:string|number, regex?:string|RegExp}];

        /*
         Alternative option to determine actual class type. This attribute has priority over 'rules' attribute.
         It defines filter to select list of classes available by class name. ID of selected class will be stored
         in selector property
         */
        classNameRegex?:string;
    }

    /*
     Property name ID (in `referenceTo` class) used as reversed reference property for this one. Optional. If set,
     Flexilite will ensure that referenced class does have this property.
     'reversed property' is treated as slave of master definition. It means the following:
     1) reversed object ID is stored in [Value] field (master's object ID in [ObjectID] field)
     2) when master property gets modified (switches to different class or reverse property) or deleted, 
     reverse property gets deleted
     */
    reversePropertyID?:number;
    /*
     or
     */
    $reversePropertyName?:string;

    /*
     If true, linked item(s) will be loaded together with master object and injected into its payload
     */
    autoFetch?:boolean;

    /*
     Defines number of items fetched as a part of master object load. Applicable only if autoFetch === true
     */
    autoFetchLimit?:number;
}

/*
 Class property metadata
 */
interface IClassProperty
{
    /*
     Fast lookup for this property is desired
     */
    indexed?:boolean;

    /*
     This property is unique among all class objects. Properties with role ID or Code are assumed to be unique
     */
    unique?:boolean;

    /*
     If set and actual value is text, its content will be indexed for full text search
     */
    fastTextSearch?:boolean;

    /*
     What is functional role of this property in the class?
     */
    role?:PROPERTY_ROLE;

    ui?:IPropertyUISettings;
    rules:IPropertyRulesSettings;

    /*
     Regulates whether this property is excluded from change log records. By default, all changes
     for all objects and properties are logged. If set to true, it will be excluded from change log payload
     */
    noTrackChanges?:boolean;

    /*
     Extended data for REFERENCE and OBJECT types
     */
    reference?:IObjectPropertyDefinition;

    dateTime?:'dateOnly' | 'timeOnly' | 'dateTime';

    // TODO
    subType?:string;

    enumDef?:IEnumPropertyDefinition;

    defaultValue?:any;

    /*
     List of volatile, non-storable attributes, which are used as instructions for property alteration
     */
    $renameTo?:string;

    /*
     Applicable when property type changes from scalar to range type. In this case, $highBoundPropertyName will have
     name of property which value will be used as high bound of range. If not specified, own property value will be
     used for both low and high bound values
     */
    $lowBoundPropertyName?:string;
    $highBoundPropertyName?:string;
}

type IClassPropertyDictionary = {[propID:string]:IClassProperty};

/*
 Structure of .classes.Data
 */
interface IClassDefinition
{
    ui?:{
        defaultTemplates?:{
            form?:string;
            table?:string;
            item?:string;
            view?:string;
        };

        /*
         NameID
         */
        title?:number;
    };

    /*
     Properties definition for view generation
     */
    properties:IClassPropertyDictionary;
}

type IClassPropertyDictionaryByName = {[propName:string]:IClassProperty};


