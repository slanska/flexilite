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
     Property is alternative unique object ID
     */
    ID = 0x04,
    IDPart1 = 0x04,
    IDPart2 = 0x05,
    IDPart3 = 0x06,
    IDPart4 = 0x07
}

declare const enum PROPERTY_TYPE
{
    TEXT,
    INTEGER,
    NUMBER,
    BOOLEAN,

    /*
     Reference to another object or collection of objects
     */
    OBJECT,
    ENUM,
    BINARY,
    UUID,
    DATETIME,

    /*
     Presented as text but internally stored as name ID. Provides localization
     */
    NAME,
    JSON

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
     Dynamic list of items to select. In this case ENUM behaves very similar to OBJECT property, boxed_reference mode
     */
    classID?:number;
    /*
     Optional filter to select only certain values in the class
     */
    filter?:any;

    /*
     Hard coded list of items to select from
     */
    items:[{ID:string | number, Title?:string, NameID?:NameId}]
}

interface IObjectPropertyDefinition
{
    classID?:number;

    type:OBJECT_REFERENCE_TYPE;

    /*
     if type = BOXED_OBJECT, this attribute helps to determine actual class ID of boxed object. This feature allows to dynamically
     extend objects with different classes. If this attribute is set, classID attribute is not used. Also, this
     attribute is used to prepare list of class IDs available for selection when initializing new master object.
     */
    boxedObjectResolve?:{
        /*
         Property used as a source value to determine actual class type of boxed object
         */
        selectorPropID?:number;

        /*
         List of values: exactValue, class ID and optional regex. If value from selector property is equal to exactValue or
         matches regex, corresponding class ID is selected.
         Also, list of class IDs is used to build list of available classes when user creates a new master object and needs
         to select specific class. In this case, 'exactValue' attribute is used if specified. If it is not specified,
         selector value is expected to be supplied to determine actual class type
         */
        rules?:[{ classID:number, exactValue?:string|number, regex?:string}];

        /*
         Alternative option to determine actual class type. This attribute has priority over 'rules' attribute.
         It defines filter to select list of classes available for the OBJECT property. ID of selected class will be stored
         in selector property
         */
        classNameRegex?:string;
    }

    /*
     Property name ID (in `referenceTo` class) used as reversed reference property for this one. Optional. If set,
     Flexilite will ensure that referenced class has this property
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
    indexed?:boolean;
    unique?:boolean;
    role?:PROPERTY_ROLE;

    ui?:IPropertyUISettings;
    rules:IPropertyRulesSettings;

    trackChanges?:boolean;

    /*
     Extended data for REFERENCE type
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
    };

    /*
     Properties definition for view generation
     */
    properties: {[propID:number]:IClassProperty};
}

type IClassPropertyDictionary = {[propName:string]: IClassProperty};
