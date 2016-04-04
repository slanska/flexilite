/**
 * Created by slanska on 2016-03-27.
 */

/*
 Declarations for .classes Data
 */

declare type NameId = number;
declare type NameIdOrString = NameId | string;

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
     Property is alternative unique object ID. Once set, shouldn't be changed
     */
    ID = 0x04,
    IDPart1 = 0x04,
    IDPart2 = 0x05,
    IDPart3 = 0x06,
    IDPart4 = 0x07,

    /*
     Another alternative ID. Unlike ID, can be changed
     */
    Code = 0x08
}

declare const enum PROPERTY_TYPE
{
    TEXT = 0,
    INTEGER = 1,

    /*
     Stored as integer * 10000. Corresponds to Decimal(19,4). (The same format used by Visual Basic)
     */
    DECIMAL = 2,

    /*
     8 byte float value
     */
    NUMBER = 3,

    /*
     True or False
     */
    BOOLEAN = 4,

    /*
     Boxed object or collection of objects.
     'boxed_object':
     referenced object stored as a part of master object. It does not have its own ID and can be accessed
     only via master object. Such object can have other boxed objects or boxed references, but not LINKED_OBJECT references
     (since it does not have its own ID)
     */
    OBJECT = 5,

    /*
     Selectable from fixed list of items
     */
    ENUM = 6,

    /*
     Byte array (Buffer). Stored as byte 64 encoded value
     */
    BINARY = 7,

    /*
     16 byte buffer. Stored as byte 64 encoded value (takes 22 bytes)
     */
    UUID = 8,

    /*
     8 byte double, corresponds to Julian day in SQLite
     */
    DATETIME = 9,

    /*
     Presented as text but internally stored as name ID. Provides localization
     */
    NAME = 10,

    /*
     Arbitrary JSON object, not processed by Flexi
     */
    JSON = 11,

    /*
     'linked_object':
     referenced object is stored in separate row, has its own ID, referenced via row in [.ref-values]
     and can be accessed independently from master object.
     This is most flexible option.
     */
    LINK = 12
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
 ip4 address
 ip6 address

 */

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
 Bit flags that determine how referenced object is stored and accessed
 */
declare const enum OBJECT_REFERENCE_TYPE
{
    /*
     'linked_object':
     referenced object is stored in separate row, has its own ID, referenced via row in [.ref-values]
     and can be accessed independently from master object. If reversed
     This is most flexible option.
     */
    LINKED_OBJECT = 0x01,

    /*
     'boxed_object':
     referenced object stored as a part of master object. It does not have its own ID and can be accessed
     only via master object. Such object can have other boxed objects or boxed references, but not LINKED_OBJECT references
     */
    BOXED_OBJECT = 0x02,

    /*
     'boxed_reference':
     referenced object is stored in separate row, like LINKED_OBJECT. But reference to this object is stored inside of
     master object data. Object ID used in this case is user-defined ID, thus referenced class must have a property with role = ID.
     */
    BOXED_REFERENCE = 0x04
}

interface IEnumPropertyDefinition
{
    /*
     Hard coded list of items to select from. Either Text or TextID are required to serve
     */
    items:[{ID:string | number, Text?:string, TextID?:NameId}]
}

interface IObjectPropertyDefinition
{
    classID?:number;

    /*
     if type = BOXED_OBJECT, this attribute helps to determine actual class ID of boxed object. This feature allows to dynamically
     extend objects with different classes. If this attribute is set, classID attribute is not used. Also, this
     attribute is used to prepare list of class IDs available for selection when initializing new master object.
     */
    resolve?:{
        /*
         Property ID used as a source value to determine actual class type of boxed object
         */
        selectorPropID?:number;

        /*
         List of values: exactValue, class ID and optional regex. If value from selector property is equal to exactValue or
         matches regex, corresponding class ID is selected.
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
     Flexi will ensure that referenced class does have this property
     */
    reversePropertyID?:number;

    /*
     If true, linked item(s) will be loaded together with master object and injected into its payload
     */
    autoFetch?:boolean;
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
     Sets JSON path for payload output (returned by API requests). If not set, property ID will be used
     (e.g.: '.123')
     */
    jsonPath?:string;

    /*
     Alternative JSON path for exported payload output. Normally, this is needed to exchange data with
     other systems. If not set, current property name will be used. (e.g.: '.LastName')
     */
    exportJsonPath?:string;

    /*
     Extended data for REFERENCE and OBJECT types
     */
    reference?:IObjectPropertyDefinition;

    dateTime?:'dateOnly' | 'timeOnly' | 'dateTime';

    // TODO
    subType?:string;

    enumDef?:IEnumPropertyDefinition;

    defaultValue?:any;
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
        title?: number;
    };

    /*
     Properties definition for view generation
     */
    properties:{[propID:number]:IClassProperty};
}

type IClassPropertyDictionary = {[propName:string]:IClassProperty};
