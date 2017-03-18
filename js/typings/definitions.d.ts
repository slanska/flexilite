/**
 * Created by slanska on 2017-01-23.
 */

/*
 This TypeScript definition module contains JSON contracts for Flexilite functions
 */

/*
 Property types
 */
declare type PropertyType =
    /*
     Text type
     */
    'text' |

        /*
         Property is stored as integer value pointing to row in .names table.
         This type is compatible with 'text' type and gives the following advantages:
         a) more compact storage
         b) automatic full text indexing
         c) i18n support. Queries will return text data translated based on cultural context.

         Regular indexing is also available, though only unique indexing is what really makes sense for 'name' type (as values are full-text indexed anyway)
         */
        'name' |

        /*
         Up to 64 bit integer
         */
        'integer' |

        /*
         Double precision float
         */
        'number' |

        /*
         true or false, obviously
         */
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
         property definition must have refDef filled (IReferencePropertyDefinition).
         Usually reference properties are defined in both related classes. One class is master,
         second is linked.
         */
        'reference' |

        /*
         Property can be of any type. No validation or additional processing is applied.
         Property can be still indexed.
         */
        'any' |

        /*
         JSON type
         */
        'json' |

        /*
         Stored as integer with 4 decimal places.
         For example, $100.39 will be stored as 1003900
         (the same storage format used by Visual Basic script - 4 decimal point accuracy)
         */
        'money' |

        /*
         Volatile, not stored property. Accepted on input but ignored
         */
        'computed';

declare type PropertyIndexMode =
    /*
     No index is applied. This is default value
     */
    'none'

        /*
         Property is indexed for fast lookup. Duplicates are allowed. Applied for text(up to 255),
         blob (up to 255), date*, integer and float values
         */
        | 'index'

        /*
         This property is unique among all class objects. Note: properties with role ID or Code are assumed to be unique
         Data types supported are the same as for 'index'
         */
        | 'unique'

        /*
         This property is part of range definition (together with another property), either as low bound or high bound.
         SQLite RTree is used for range index and up to 4 pairs of properties can be indexed.
         Only numeric, integer or date properties can be indexed using RTRee.
         Actual mapping between properties and RTRee columns is done in IClassDefinition.rangeIndexing
         Attempt to apply range index for other property types will result in an error.
         */
        | 'range'

        /*
         Content will be indexed for full text search. Applicable to text values only.
         Name type will be indexed by default
         */
        | 'fulltext';

/*
 Type of relationship between objects.
 */
declare type RelationRule =
    /*
     Referenced object(s) are details (dependents).
     They will be deleted when master is deleted. Equivalent of DELETE CASCADE
     */
    'master' |

        /*
         Loose association between 2 objects. When object gets deleted, references are deleted too.
         Equivalent of DELETE SET NULL
         */
        'link' |

        /*
         Similar to master but referenced objects are treated as part of master object
         */
        'nested' |

        /*
         Object cannot be deleted if there are references. Equivalent of DELETE RESTRICT
         */
        'dependent' ;

/*
 User-friendly and internal way to specify class, property or name
 */
interface IMetadataRef {
    /*
     User supplied value. During save will be converted to $id which will be used thereafter
     */
    $name?: string;
    /*
     or
     */
    $id?: number;
}

declare interface TMixinClassDef {
    classRef?: IMetadataRef | IMetadataRef[],
    dynamic?: {
        selectorProp: IMetadataRef;
        rules: {
            regex: string | RegExp,
            classRef: IMetadataRef
        }[];
    }
}

declare interface IReferencePropertyDef extends TMixinClassDef {
    /*
     Property name ID (in `classRef` class) used as reversed reference property for this one. Optional. If set,
     Flexilite will ensure that referenced class does have this property (by creating if needed).
     'reversed property' is treated as slave of master definition. It means the following:
     1) reversed object ID is stored in [Value] field (master's object ID in [ObjectID] field)
     2) when master property gets modified (switches to different class or reverse property) or deleted,
     reverse property definition also gets deleted
     */
    reverseProperty?: IMetadataRef;

    /*
     Defines number of items fetched as a part of master object load. Applicable only > 0
     */
    autoFetchLimit?: number;

    autoFetchDepth?: number;

    /*
     Optional relation rule when object gets deleted. If not specified, 'link' is assumed
     */
    rule?: RelationRule;
}

/*
 Enum definition: either $id or $name or items
 */
declare interface IEnumPropertyDef extends IMetadataRef {
    items?: IEnumItem[];
}

declare type PropertySubType =
    'text'
        | 'email'
        | 'ip'
        | 'password'
        | 'ip6v'
        | 'url'
        | 'image'
        | 'html';
// TODO To be extended

/*
 Contract for standard property validation rules and constraints
 */
declare interface IPropertyRulesSettings {
    type: PropertyType;

    subType?: PropertySubType;

    /*
     Number of occurences for the single object.
     For regular required properties both minOccurences and maxOccurences are 1
     For regular optional properties, 0 and 1 respectively
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
    id: string | number,

    text: IMetadataRef;
}

interface IEnumPropertyDefinition {
    /*
     Hard coded list of items to select from. Either Text or TextID are required to serve
     */
    items: [IEnumItem]
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

    // TODO
    // ui?: IPropertyUISettings;

    /*
     Regulates whether this property is excluded from change log records. By default, all changes
     for all objects and properties are logged. If set to true, it will be excluded from change log records
     */
    noTrackChanges?: boolean;

    /*
     Required if rules.type == 'reference'
     */
    refDef?: IReferencePropertyDef;

    dateTime?: 'dateOnly' | 'timeOnly' | 'dateTime' | 'timeSpan';

    enumDef?: IEnumPropertyDef;

    defaultValue?: any;

    /*
     List of command, non-stored attributes, which are used as instructions for property alteration
     */

    /*
     Instruction to rename property
     */
    $renameTo?: string;

    /*
     Property will be removed by flexi_class_alter
     */
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
    /*
     Property names, expressions
     */
}

/*
 Structure to define query
 Mimics SQL SELECT
 'where' can be used standalone.
 Query is evaluated for presence of 'where' or 'orderBy' attribute. If not any of those attributes are found, query body is treated as 'where' clause.
 Example: {Prop1: 123, Prop2: "abc"} is treated as {where: {Prop1: 123, Prop2: "abc"}}
 */
declare interface IQueryDef {
    select?: IQuerySelectDef;
    from?: string;
    filter?: IQueryWhereDef;
    orderBy?: IQueryOrderByDef;
    limit?: number;
    skip?: number;
    bookmark?: string;
    user?: IUserContext;
    fetchDepth?:number;
}

/*
 Current user context
 */
declare interface IUserContext {
    id: string,
    roles?: string[],
    culture?: string
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
    | '=' | '==' | '!=' | '<>' | '<' | '>' | '<=' | '>=' |

    /* Set operations */

    /* A B is the set that contains all the elements in either A or B or both:
     Example 1: If A = {1, 2, 3} and B = {4, 5} ,  then A  B = {1, 2, 3, 4, 5} .
     Example 2: If A = {1, 2, 3} and B = {1, 2, 4, 5} ,  then A  B = {1, 2, 3, 4, 5} .
     */
    '$union' |

    /* A B is the set that contains all the elements that are in both A and B:
     Example 3: If A = {1, 2, 3} and B = {1, 2, 4, 5} ,  then A  B = {1, 2} .
     Example 4: If A = {1, 2, 3} and B = {4, 5} ,  then A  B =  .
     */
    '$intersect' |

    /* Example 5: If A = {1, 2, 3} and B = {1, 2, 4, 5} ,  then A - B = {3} .
     Example 6: If A = {1, 2, 3} and B = {4, 5} ,  then A - B = {1, 2, 3} .
     */
    '$difference';

type IClassPropertyDictionary = {[propID: string]: IClassPropertyDef};

/*
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

        /* Name text or ID */
        name?: IMetadataRef;
    };

    /*
     Properties definition for view generation
     */
    properties: IClassPropertyDictionary;

    /*
     If true, any non defined properties are allowed. Any properties in payload, that are not
     in the "properties" attribute, will be processed as names, and their name IDs will be used instead
     of property IDs. Such properties :
     a) indexed based on .names ctlv definition
     b) are not validated
     c) can be included into select or where clause
     d) will be included into query result, if their names are specified explicitly in "select" clause

     Default value: false
     */
    allowAnyProps?: boolean;

    /*
     Reserved for future use.
     Mapping for locked properties to fixed columns in [.objects] table
     Locked properties are used for more efficient access and provide limited refactoring capabilities.
     */
    columnMapping?: {
        A?: IMetadataRef;
        B?: IMetadataRef;
        C?: IMetadataRef;
        D?: IMetadataRef;
        E?: IMetadataRef;
        F?: IMetadataRef;
        G?: IMetadataRef;
        H?: IMetadataRef;
        I?: IMetadataRef;
        J?: IMetadataRef;
        K?: IMetadataRef;
        L?: IMetadataRef;
        M?: IMetadataRef;
        N?: IMetadataRef;
        O?: IMetadataRef;
        P?: IMetadataRef;
    }

    /*
     Optional set of properties that serve special purpose
     */
    specialProperties?: {
        /*
         User defined unique object ID.
         Once set, cannot be changed
         */
        uid?: IMetadataRef;

        /*
         Object Name
         */
        name?: IMetadataRef;

        /*
         Object description
         */
        description?: IMetadataRef;

        /*
         Another alternative ID. Unlike ID, can be changed
         */
        code?: IMetadataRef;

        /*
         Alternative ID that allows duplicates
         */
        nonUniqueId?: IMetadataRef;

        /*
         Timestamp on when object was created
         */
        createTime?: IMetadataRef;

        /*
         Timestamp on when object was last updated
         */
        updateTime?: IMetadataRef;

        /*
         Auto generated UUID (16 byte blob)
         */
        autoUuid?: IMetadataRef;

        /*
         Auto generated short ID (7-16 characters)
         */
        autoShortId?: IMetadataRef;
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
        A0: IMetadataRef;
        A1?: IMetadataRef;
        B0?: IMetadataRef;
        B1?: IMetadataRef;
        C0?: IMetadataRef;
        C1?: IMetadataRef;
        D0?: IMetadataRef;
        D1?: IMetadataRef;
        E0?: IMetadataRef;
        E1?: IMetadataRef;
    }

    /*
     Optional full text indexing. Maximum 4 properties are allowed for full text index.
     These properties are mapped to X1-X4 columns in [.full_text_data] table
     */
    fullTextIndexing?: {
        X1?: IMetadataRef;
        X2?: IMetadataRef;
        X3?: IMetadataRef;
        X4?: IMetadataRef;
        X5?: IMetadataRef;
    }

    /*
     (Optional) list of base classes. Defines classes that given class can 'extend', i.e. use their
     properties
     */
    mixin?: TMixinClassDef;

    /*
     Optional storage mode. By default - 'flexi-data', which means that data will be stored in Flexilite
     internal tables (.objects and .ref-values).
     'flexi-rel' means that data will not stored anywhere, and class with this storage mode will be serving
     as a proxy to many-to-many relation.
     If class has 'flexi-rel' storage mode, it is required to have exactly 2 properties (of any type)
     and storageFlexiRel attribute must be configured, to define relationship between 2 other classes in
     Flexilite database
     */
    storage?: 'flexi-data' | 'flexi-rel';
    storageFlexiRel?: {
        master: IStorageFlexiRelProperty;
        detail: IStorageFlexiRelProperty;
    }

}

interface IStorageFlexiRelProperty {
    ownProperty: IMetadataRef;
    refClass: IMetadataRef;
    refProperty: IMetadataRef;
}

type IClassPropertyDictionaryByName = {[propName: string]: IClassPropertyDef};