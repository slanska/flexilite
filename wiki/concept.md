## Flexilite conceptual model

Main concepts in the Flexilite ("F") are *classes*, *properties*, **schemas*,*collections*,
 *items* and *names*.
 
### Class
Corresponds to table structure in RDBMS. Has plain list of properties. Has constraints,
validation rules and other metadata. Class definitions are stored in
`.classes` table. Every class maintains updatable SQLite view, named after
class name. This view provides table-like access to class data (including 
insert, update, delete and indexed select operations), 
transparent to the end user. View structure includes all scalar 
properties as well as properties

### Object
Instance of class. Can be standalone, with its own ID or nested 
(a.k.a embedded or boxed).
Standalone objects are similar to rows in RDBMS. Set of standalone objects 
for the given class form list of items, similar to table in RDBMS.
Nested objects are *virtually* enclosed into payload of their master objects, they 
do not have ID and not included into class's list of items. These objects,
though, are still managed by their class definition and structure,
follow all constraints, validation rules and other metadata. Term *virtual* 
means that in fact they might be stored as standalone objects, but from
standpoint of master object they are still nested, i.e. loaded together
with master object load, and destroyed when master object gets deleted.
Standalone objects are always stored as separated items and accessible individually
by their ID or other filter. Selected scalar properties (including properties 
of nested objects) can be marked as indexed or unique. 
Standalone objects are stored in `.objects` table.

### Property
Single named attribute of object. Can be scalar (integer, text, boolean etc.) 
or composite (linked object). Linked object can be either nested (or boxed) or
another referenced standalone item. Also, property can be defined as single
or array values. This is defined via property's attributes `minOccurences`
and `maxOccurences` (terminology borrowed from XML/XSD). For example,
`minOccurences=0, maxOccurences=1` defines single optional (not require, or NULL) value. 
`minOccurences=1, maxOccurences=1` - required (NOT NULL) value.
`minOccurences=0, maxOccurences=100` defines optional array of items, with
maximum allowed capacity of 100. Property definition is stored in JSON
field in `.classes` table. With help of reference property it is possible
to build object graphs of arbitrary complexity. Properties of single 
referenced objects are accessed via dot notation, e.g. 
"Person.Address.City". Access to arrays is documented later in this document.

### Name
String value. Has its own unique ID and some other attributes, used, in
particular, for translation and display. Every class and property has name. Also,
for class' properties there is a special data type - NAME. 
While similar to TEXT type, NAME type provides compact storage has 
out-of-box support for translation, formatting, icon representation and so on.
 
### Schema
Defines mapping between class properties and actual JSON payload. Every schema
is associated with class, and class may have multiple schemas. Every 
object has SchemaID property, which refers to actual mapping of its
data. Actual object payload may have arbitrary structure, as long as individual
properties are accessed through JSON path (dot notation and array index qualifiers).
Purpose of schema is to provide access to the object's property values
by mapping to actual payload structure. Every class has default schema (used for
new objects)

## Duck Typing
Classes in "F" are standalone. There is no formal relationship like
inheritance between classes. Instead, "F" utilizes concept of duck typing:
if it looks like a duck, swims like a duck, walks like a duck (etc. etc.)
then this is a duck. In other words, if class A has all properties of class
B (compared by their `nameAs` attributes, rather than by property IDs), then
B is considered as a subclass of A.
  
## Nested classes and polymorphism

### Resolve class 

### Select class


 

