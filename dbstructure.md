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
    schemaNameRegex: string,
    ranges:[{from:number, to:number, schemaNameRegex:string}]}`

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