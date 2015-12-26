# Data Refactoring Patterns and Their Implementation in Flexilite

## Terminoogy

* Table =  Class. Class names are normally singular: 'Order', 'Person', 'Car' etc.
Also, classes may have optional plural names (to be used in collections). 
'Orders', 'Persons', 'Cars' etc.
* Column = Property
* Row = Object (also, 'Record', 'Item')
* Field (of Row for the given Column) = Value (of Object for the given Property)
* Scalar property: one of the following data types -
Text, Boolean, Integer, Number, BLOB, DateTime, Enum, GUID
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

### Save JSON or XML object

### Add property

### Rename class

### Rename property

### Drop property

### Drop class

### Change type of scalar property

### Change validation rules for property

### Create index on property for the fast lookup

### Drop index on property

### Create full text search index on text property

### Change class type of reference property

### Extract property/properties into a separate class

### Merge selected objects into another class (on property level)

### 



