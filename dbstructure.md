# Database structure

### .names
NameID
Value
PluralOf
AliasOf
Data
    `{translations: {[culture:string]: string},
    icon:string}`

### .schemas
SchemaID
NameID
Variation   `NULL` or SchemaID
Data
    `{properties: {[propertyNameID:number]: {
    rules: {
    type:string,
    minOccurences:number,
    maxOccurences: number,
    regex: string,
    reference: {collectionID:number,
        reversePropertyID:number}
    },
    meta: {},
    map: {
    jsonPath:string,
    refPropertyID: {
    }
    }
    }}}`

### .collections
CollectionID
NameID
BaseSchemaNameID
A-J
ctlo
Capacity
ViewOutdated
AccessRules
SchemaRules
    `{
    properties: {[propId:number]: {unique:boolean}}
    schemaNameRegex: string,
    ranges:[{from:number, to:number, schemaNameRegex:string}]
    }`

Collection may have multiple schemas
Schemas have versions (grouped by name ID). More recent version has bigger Version value
Collection's base schema means latest version of schema with given name

Property ID is in fact name ID. This is meaningful name that is used to access object properties.
when renaming property (changing its ID), this change gets applied to all schema versions and all
collections that use this schema as base one.
Mapping is not affected. 

### .objects
ObjectID
CollectionID
SchemaID
A-J
ctlo
Data

### .ref-values
ObjectID
CollectionID
PropertyID
PropIndex
ctlv
LinkedObjectID
Data

