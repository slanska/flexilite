# Data Refactoring Patterns and Their Implementation in Flexilite

## Terminoogy

* Table =  Class. Class names are normally singular: 'Order', 'Person', 'Car' etc.
Also, classes may have optional plural names (to be used in collections). 
'Orders', 'Persons', 'Cars' etc.
* Column = Property
* Row = Object (also, 'Record', 'Item')
* Field (of Row for the given Column) = Value (of Object for the given Property)
* Scalar property: one of the following data types -
Text, Boolean, Integer, Number, BLOB, DateTime, Enum, GUID, Name
* Reference property: named link between 2 objects (master-object and referenced-object, or linked-object). 
Reference can be unidirectional (from master to linked), or bidirectional 
(in addition to 'master-to-linked' there is 'linked-to-master' relation, also
called reverse reference, by its own name). For example: 'Car' class has reference
property called 'Engine', which is link to the 'CarEngine' class. 
* Collection (or array): list of scalar or reference values. Individual items in collections
are accessed via sequential index. Index is 1 based (i.e. collection called 'Parts' 
with 10 items can accessed
as Parts[1], Parts[2] and so on). Index 0 is used to distinct between single and collection value.


### Create class
Inserts row into _.classes_ table. Generates schema definition with 
mapping between class property IDs and payload. Custom mapping can be provided
as a parameter. Inserts row into _.schemas_ table. New view named exactly
as class is generated.

### Save JSON or XML object

### Add property
Updates class record with new property metadata. Creates copy of previous
default schema, with new mapping (custom mapping can be provided as
a parameter). View is re-generated.

### Rename class
Updates class NameID field. Updates schemas' NameID.
New name should not be used by other class.

### Rename property
Updates definition of property in class, by adding/changing `nameAs` attribute
of property metadata. No other changes are made to class or schemas. New
property name is treated as an alias. View gets regenerated.

### Defining default value for property

### Change property scalar type, validation rules

### Make property indexed or unique
Updates all class' objects, extracts property values from JSON and places
them into fixed column (A..J). One of the few heavy refactoring operations in
Flexilite.

### Adding computed property
Expression for computed property should be a valid SQL expression, 
which may refer to other (non computed) columns. Class record is updated,
view is regenerated. No other changes are required.

### Drop property
Property definition is removed from class definition. 
View is regenerated. No other changes are required.

### Drop class
Class record, view definition, related schemas and objects get deleted.

### Change type of scalar property

### Change validation rules for property

### Create index on property for the fast lookup

### Drop index on property

### Create full text search index on text property

### Change class type of reference property

### Rollback previous refactoring

### Extract property/properties into a separate class

### Extract property/properties into a separate class as single nested object
Create new class definition (if it does not exist yet). Creates schema
for new class. Updates class definition, regenerates view.

### Convert single property into array


### Merge selected objects into another class (with property mapping)

#### Text -> Symbol -> Enum -> Reference -> Enum -> Symbol -> Text

Generate new symbols for existing text values. Do not change existing text values
When value changes, replace it with symbol ID



#### Merge properties: many properties -> one property

Add computed property with expression
Preserve this property
Remove old properties

#### Split properties: one property -> many properties

Update properties
Remove old property

#### Scalar property -> array -> scalar property

Update property definition

#### Properties -> Nested object -> Reference -> Collection of references -> Reference -> Nested object -> Properties

#### Move selected objects to another class, with property mapping

#### Structurally split: one object -> many objects from different classes, referencing each other

#### Structurally merge: many objects, with join criteria (reference or value) -> one object

#### Change property: type, validation rules

#### Add computed property: expression

Existing data is not changed. Read returns result of expression, update deletes old value

#### Preserve computed property
flexi_prop_preserve

#### Save object graph (using JSON)

#### Retrieve object graph: collection, by filter and sorting criteria



