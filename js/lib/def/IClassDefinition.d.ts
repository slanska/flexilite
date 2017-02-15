/**
 * Created by slanska on 2016-03-27.
 */

/*
 Declarations for .classes Data
 */

// /<reference path="../../typings/DBDefinitions.ts"/>

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


/*
 Enum item definition
 */
interface IEnumItem
{
    /*
     Required attribute: string or number item ID
     */
    ID:string | number,

    /*
     Either $Text or TextID should be specified. $Text has priority over TextID.
     Internally TextID is stored, $Text is removed after obtaining name ID
     */
    $Text?:string,
    TextID?:NameId
}
interface IEnumPropertyDefinition
{
    /*
     Hard coded list of items to select from. Either Text or TextID are required to serve
     */
    items:[IEnumItem]
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
     $id attribute is not used. Also, this attribute is used to prepare list of class IDs available
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
     This property is unique among all class objects. Note: properties with role ID or Code are assumed to be unique
     */
    unique?:boolean;

    /*
     If set and actual value is text, its content will be indexed for full text search
     */
    fastTextSearch?:boolean;

    /*
     Functional role of this property in the class?
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
     If set, this property will be indexed using r-tree. For type PROP_TYPE_RANGE* this attribute has to be set to one
     of the following values: RNG_MAP_RANGE_A, RNG_MAP_RANGE_B, RNG_MAP_RANGE_C, RNG_MAP_RANGE_D.
     This is a temporary value
     */
    $rangeDef?:Range_Column_Mapping;
}

type IClassPropertyDictionary = {[propID:string]:IClassProperty};

interface IPropertyIdentifier
{
    $propertyName?:string;
    propertyID?:number;
}
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

    /*
    Mapping properties to fixed columns in [.objects] table
     */
    columnMapping?:{
        A?:IPropertyIdentifier;
        B?:IPropertyIdentifier;
        C?:IPropertyIdentifier;
        D?:IPropertyIdentifier;
        E?:IPropertyIdentifier;
        F?:IPropertyIdentifier;
        G?:IPropertyIdentifier;
        H?:IPropertyIdentifier;
        I?:IPropertyIdentifier;
        J?:IPropertyIdentifier;
        K?:IPropertyIdentifier;
        L?:IPropertyIdentifier;
        M?:IPropertyIdentifier;
        N?:IPropertyIdentifier;
        O?:IPropertyIdentifier;
        P?:IPropertyIdentifier;
    }

    rangeIndexing?:{
        A0:IPropertyIdentifier;
        A1?:IPropertyIdentifier;
        B0?:IPropertyIdentifier;
        B1?:IPropertyIdentifier;
        C0?:IPropertyIdentifier;
        C1?:IPropertyIdentifier;
        D0?:IPropertyIdentifier;
        D1?:IPropertyIdentifier;
    }
}

type IClassPropertyDictionaryByName = {[propName:string]:IClassProperty};


