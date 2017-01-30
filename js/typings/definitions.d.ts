/**
 * Created by slanska on 2017-01-23.
 */

/*
 This TypeScript definition module contains JSON contracts for Flexilite functions
 */

/*
 Property types
 */
declare type IPropertyType =
    'text' |

        /*
         Up to 64 bit integer
         */
        'integer' |

        /*
         Double precision float
         */
        'number' |
        'boolean' |

        /*
         Stored as Julian double value. Integer part - number of days, fractional - time of day
         Precision is
         */
        'date' |
        'timespan' |
        'datetime' |

        /*
         BLOB
         */
        'binary' |
        'uuid' |

        /*
         Enumerated value. If property type is 'enum', property definition must have enumDef filled.
         enumDef can have either list of values or enum name or enum ID. When processing ID takes
         precedence, then name, then list of values.
         If list is passed, it will be processed and saved in .enums table.
         */
        'enum' |

        /*
         Property is a relation and references another object(s). If this property type is set,
         property definition must have refDef filled (IReferencePropertyDefinition)
         */
        'reference' |

        /*
         Property can be of any type. No validation or additional processing is applied.
         Property can be still indexed
         */
        'any';

declare type PropertyIndexMode =
    /*
     No index is applied. This is default value
     */
    'none'

        /*
         Property is indexed for fast lookup. Duplicates are allowed
         */
        | 'index'

        /*
         This property is unique among all class objects. Note: properties with role ID or Code are assumed to be unique
         */
        | 'unique'

        /*
         This property is part of range definition (together with another property), either as low bound or high bound.
         SQLite RTree is used for range index and up to 5 pairs of properties can be indexed.
         Only numeric, integer or date properties can be indexed using RTRee.
         Actual mapping between properties and RTRee columns is done in IClassDefinition.rangeIndexing
         Attempt to apply range index for other property types will result in an error.
         */
        | 'range'

        /*
         Content will be indexed for full text search. Only text values are indexed
         */
        | 'fulltext';

/*
 Type of relationship between objects.
 */
declare type RelationType =
    /*
     References object(s) are details.
     They will be deleted when master is deleted
     */
    'master-to-details' |

        /*
         Referenced objects are treated as part of master object, but accessed via additional
         object property
         */
        'nested' |

        /*
         Many to many
         */
        'association' |

        /*
         Referenced class extends this class, in one-to-one relationship
         */
        'extend' |

        /*
         Opposite to 'master-to-detail'
         */
        'detail-to-master';

declare interface IReferencePropertyDef {
    classID?: number;
    /*
     or
     */
    $className?: string;

    /*
     Property name ID (in `referenceTo` class) used as reversed reference property for this one. Optional. If set,
     Flexilite will ensure that referenced class does have this property (by creating if needed).
     'reversed property' is treated as slave of master definition. It means the following:
     1) reversed object ID is stored in [Value] field (master's object ID in [ObjectID] field)
     2) when master property gets modified (switches to different class or reverse property) or deleted,
     reverse property definition also gets deleted
     */
    reversePropertyID?: number;
    /*
     or
     */
    $reversePropertyName?: string;

    $reverseMinOccurences?: number;
    $reverseMaxOccurences?: number;

    /*
     Defines number of items fetched as a part of master object load. Applicable only > 0
     */
    autoFetchLimit?: number;

    /*

     */
    relationType?; RelationType;
}

declare interface IEnumPropertyDef {
    enumId: number;
    /*
    or
     */
    $enumName?:string;
    /*
    or
     */
    items?: IEnumItem[];
}

declare type NameId = number;

declare interface IPropertyDef {
    rules: {
        type: IPropertyType;
        minOccurences?: number;
        maxOccurences?: number;
        regex?: string;
    },
    indexing?: PropertyIndexMode;
    name: string,
    defaultValue?: Object;

    /*
     Required if rules.type == 'reference'
     */
    refDef?: IReferencePropertyDef;

    /*
     Required if rules.type == 'enum'
     */
    enumDef?: IEnumPropertyDef;
}

declare interface IPropertyRulesSettings {
    type: IPropertyType;

    // TODO subType?: PropertySubType;

    /*
     Number of occurences for the single object.
     For normal required properties both minOccurences and maxOccurences are 1
     For normal optional properties, 0 and 1 respectively
     For arrays, minOccurences must be non negative value and maxOccurences must be not smaller than minOccurences
     */
    minOccurences?: number; // default: 0
    maxOccurences?: number; // default: 1

    /*
     For text and binary properties
     */
    maxLength?: number; // default: no limit

    /*
     Applicable to integer, number, date* types
     */
    minValue?: number; // default: no limit
    maxValue?: number; // default: no limit

    /*
     Normally applied to text types, but will be also applied to integer type by
     converting it to text first and then performing validation
     */
    regex?: string; // Value casted to text and then tested for matching regex
}

/*
 Enum item definition
 */
declare interface IEnumItem {
    /*
     Required attribute: string or number item ID
     */
    ID: string | number,

    /*
     Either $Text or TextID should be specified. $Text has priority over TextID.
     Internally TextID is stored, $Text is removed after obtaining name ID
     */
    $Text?: string,
    TextID?: NameId
}

interface IEnumPropertyDefinition {
    /*
     Hard coded list of items to select from. Either Text or TextID are required to serve
     */
    items: [IEnumItem]
}

/*
 'Object' property settings
 */
interface IObjectPropertyDefinition {
    classID?: number;
    /*
     or
     */
    $className?: string;

    /*
     if prop.rules.type = 'object', this attribute helps to determine actual class ID of boxed/nested object.
     This feature allows to dynamically extend objects with different classes. If this attribute is set,
     classID attribute is not used. Also, this attribute is used to prepare list of class IDs available
     for selection when initializing new master object.
     */
    resolve?: {
        /*
         ID of property in the same object that is used as a source value to determine actual class type of boxed object
         */
        selectorPropID?: number;

        /*
         List of values: exactValue, class ID and optional regex. If value from selector property is equal to exactValue or
         matches regex, corresponding class ID is selected. Matching is applied lineary, starting from 1st item in rules array.
         Also, list of class IDs is used to build list of available classes when user creates a new object and needs
         to select specific class. In this case, 'exactValue' attribute is used to populate selectorPropID if specified.
         If it is not specified, selector value will be set to selected class ID
         */
        rules?: [{classID: number, exactValue?: string|number, regex?: string|RegExp}];

        /*
         Alternative option to determine actual class type. This attribute has priority over 'rules' attribute.
         It defines filter to select list of classes available by class name. ID of selected class will be stored
         in selector property
         */
        classNameRegex?: string;
    }

    /*
     Property name ID (in `referenceTo` class) used as reversed reference property for this one. Optional. If set,
     Flexilite will ensure that referenced class does have this property (by creating if needed).
     'reversed property' is treated as slave of master definition. It means the following:
     1) reversed object ID is stored in [Value] field (master's object ID in [ObjectID] field)
     2) when master property gets modified (switches to different class or reverse property) or deleted,
     reverse property definition also gets deleted
     */
    reversePropertyID?: number;
    /*
     or
     */
    $reversePropertyName?: string;

    /*
     If true, linked item(s) will be loaded together with master object and injected into its payload
     */
    autoFetch?: boolean;

    /*
     Defines number of items fetched as a part of master object load. Applicable only if autoFetch === true
     */
    autoFetchLimit?: number;
}

/*
 Bit flags of roles that property plays in its class
 */
declare const enum PROPERTY_ROLE
{
    /*
     No special role
     */
    PROP_ROLE_NONE = 0x0000,

        /*
         Object Name
         */
    PROP_ROLE_NAME = 0x0001,

        /*
         Property has object description
         */
    PROP_ROLE_DESCRIPTION = 0x0002,

        /*
         Property is alternative unique object ID. Once set, shouldn't be changed
         */
    PROP_ROLE_ID = 0x0004,

        /*
         Another alternative ID. Unlike ID, can be changed
         */
    PROP_ROLE_CODE = 0x0008,

        /*
         Alternative ID that allows duplicates
         */
    PROP_ROLE_NONUNIQUEID = 0x0010,

        /*
         Timestamp on when object was created
         */
    PROP_ROLE_CREATETIME = 0x0020,

        /*
         Timestamp on when object was last updated
         */
    PROP_ROLE_UPDATETIME = 0x0040,

        /*
         Auto generated UUID (16 byte blob)
         */
    PROP_ROLE_AUTOUUID = 0x0008,

        /*
         Auto generated short ID (7-16 characters)
         */
    PROP_ROLE_AUTOSHORTID = 0x0010
}

/*
 Class property metadata
 */
interface IClassPropertyDef {
    rules: IPropertyRulesSettings;
    /*
     Fast lookup for this property is desired
     */
    index?: PropertyIndexMode;

    /*
     Functional role of this property in the class?
     */
    role?: PROPERTY_ROLE;

    // TODO
    // ui?: IPropertyUISettings;

    /*
     Regulates whether this property is excluded from change log records. By default, all changes
     for all objects and properties are logged. If set to true, it will be excluded from change log records
     */
    // TODO Needed?
    noTrackChanges?: boolean;

    /*
     Extended data for REFERENCE and OBJECT types
     */
    reference?: IObjectPropertyDefinition;

    dateTime?: 'dateOnly' | 'timeOnly' | 'dateTime';

    // TODO
    subType?: string;

    enumDef?: IEnumPropertyDefinition;

    defaultValue?: any;

    /*
     List of volatile, non-storable attributes, which are used as instructions for property alteration
     */
    $renameTo?: string;

    /*
     Property will be removed by flexi_class_alter
     */
    $drop?: boolean;
}

declare interface IPropertyRefactorDef extends IPropertyDef {
    $renameTo?: string;
    $drop?: boolean;
}

declare interface IQueryWhereDef {

}

/*
 Columns|Expressions?, ASC\DESC
 */
declare interface IQueryOrderByDef {
}

/*
 Columns list for query definition.
 can be:
 1) '*'
 2) ['*']
 3) ["propertyName"]
 4) ["!propertyName"] - exclude property
 4) [{ "$query" : { ... } } ] //Subquery
 5) [{ "$expr" : {} ] // expression
 */
declare interface IQuerySelectDef {
}

declare interface IQueryDef {
    select?: IQuerySelectDef;
    from?: string;
    where?: IQueryWhereDef;
    orderBy?: IQueryOrderByDef;
    limit?: number;
    skip?: number;
    userId?: string;
    culture?: string;
    bookmark?: string;
}

/*
 Supported where operators
 Examples:
 {"Property1": { "$lt" : 100 } }
 {"Property1": { "$in" : [1, 2, 3] } }
 {"Property1": { "$not" : { "$in": [1, 2, 3] } } }
 {"Property1": "ABC" }

 $exists used for subquery on relation

 By default: "$eq"
 */
declare type QueryWhereOperator = '$eq' | '$ne' | '$lt' | '$gt' | '$le' | '$ge' | '$in'
    | '$between' | '$exists' | '$like' | '$match' | '$not'
    | '=' | '==' | '!=' | '<>' | '<' | '>' | '<=' | '>=';

type IClassPropertyDictionary = {[propID: string]: IClassPropertyDef};

interface IPropertyIdentifier {
    /*
     User supplied value. During save will be converted to propertyID which will be used thereafter
     */
    $propertyName?: string;
    /*
     or
     */
    propertyID?: number;
}
/*
 Structure of .classes.Data
 */
interface IClassDefinition {
    ui?: {
        defaultTemplates?: {
            form?: string;
            table?: string;
            item?: string;
            view?: string;
        };

        /*
         NameID
         */
        title?: number;
    };

    /*
     Properties definition for view generation
     */
    properties: IClassPropertyDictionary;

    /*
     If true, any non defined properties are allowed. Any properties in payload, that are not
     in the "properties" attribute, will be processed as names, and their name IDs will be used instead
     of property IDs. Such properties :
     a) cannot be indexed
     b) are not validated
     c) can be included into select or where clause
     d) will be included into query result, if '*' is specified for property name in "select" clause

     Default value: false
     */
    allowNotDefinedProps?: boolean;

    /*
     Mapping properties to fixed columns in [.objects] table
     */
    columnMapping?: {
        A?: IPropertyIdentifier;
        B?: IPropertyIdentifier;
        C?: IPropertyIdentifier;
        D?: IPropertyIdentifier;
        E?: IPropertyIdentifier;
        F?: IPropertyIdentifier;
        G?: IPropertyIdentifier;
        H?: IPropertyIdentifier;
        I?: IPropertyIdentifier;
        J?: IPropertyIdentifier;
        // K?: IPropertyIdentifier;
        // L?: IPropertyIdentifier;
        // M?: IPropertyIdentifier;
        // N?: IPropertyIdentifier;
        // O?: IPropertyIdentifier;
        // P?: IPropertyIdentifier;
    }

    /*
     Optional mapping for RTree index.
     If specified, at least A0 must be set.
     There are 5 pairs of ranges. Every range can be set by 2 different properties
     (e.g. StartTime - EndTime, or Latitude0 - Latitude1), or
     the same property can used for both low and high bound values (more practical scenario).
     Rtree indexing allows efficient search on few fields and their ranges at the time.
     Float and integer values: only values that fit into 4 byte single value are stored. Maximum and minimum
     values should be set accordingly. If not set by user, they will be set during saving to min & max
     single values
     Date/time are stored as logarithmic values (4 byte, single value)
     */
    rangeIndexing?: {
        A0: IPropertyIdentifier;
        A1?: IPropertyIdentifier;
        B0?: IPropertyIdentifier;
        B1?: IPropertyIdentifier;
        C0?: IPropertyIdentifier;
        C1?: IPropertyIdentifier;
        D0?: IPropertyIdentifier;
        D1?: IPropertyIdentifier;
        E0?: IPropertyIdentifier;
        E1?: IPropertyIdentifier;
    }
}

type IClassPropertyDictionaryByName = {[propName: string]: IClassPropertyDef};