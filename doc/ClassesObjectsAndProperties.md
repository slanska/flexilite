## Classes, Objects and Properties

Classes, objects and properties are fundamental pieces of Flexilite design. They are sort of equivalents of tables, records and columns
in a regular RDBM, but with a number of extended attributes and features which make Flexilite distinctive from a typical
relational database.

Here is short list of their specific features:
* All objects are stored as records in single table (**[.objects]**) and have ClassID column which determines class to which they belong to.
This storage concept opens a lot of interesting possibilities which are not possible and difficult to do in the regular RDBMS.

* Auto-generated object IDs are integer value and are unique within entire database, not just one table.

* Objects may optionally have user defined ID (UID), which must be unique within class scope.

* Information on class definitions is stored in **[.classes]** table, in JSON format, and includes full metadata on class itself, its properties
and optional custom meta information (e.g. UI generation info)

* Classes (and individual properties) can have arbitrary user metadata

* Properties are recognized by their names (for example, 'OrderNumber' or 'Work_Email'). Properties shape common semantic space of Flexilite database. From standpoint of data schema,
 any class and any object may have any property.

* There is no inheritance or other relationship between classes. Flexilite uses duck typing, i.e. checks actual presence of property definitions
 for given classes. Example: if class A has properties X, Y, Z, and class B has properties X, Y, Z, W, then class A is a super class of class B.
 Also, "F" supports mixins, i.e. composing class from other classes.

* Properties have names (which are [symbols](./DataTypes.md)) and IDs. Every class has its own set of uniquely identified properties.
Example: classes A and B both have property called 'CreateDate', but internally there will be 2 property records, with different IDs and
 same NameID (pointing to 'CreateDate' symbol). These 2 properties will be considered semantically the same, despite the fact that they may have
 different types, validation rules etc.

* Actual values for objects are stored in one table called **[.ref-values]**. This table serves as a main storage facility, following
Entity-Attribute-Value pattern. Every value is stored in its own record, with set of flags and other attributes. Though EAV is considered by
many developers as anti-pattern, the way how it is used by Flexilite makes it a good fit in terms of performance and flexibility.
For the user all these internals of storage are hidden and stored data is available through either SQLite virtual tables, JSON output or Lua tables.

* **[.ref-values]** table keeps its data in clustered index by object ID, so values belonging to the same object will be physically placed together,
on one (mostly) or more adjacent pages in the data file.

* The following functions - flexi_ClassDef_create, flexi_class_alter, flexi_class_drop - are used to create, modify and delete classes, respectively.
Create and alter functions accept class definitions in JSON format and allow wide set of changes to be applied in single operation.

* flexi_class_alter allows: a) add new properties, b) remove existing properties, c) change definitions for existing properties, including
names, type, validation rule, indexing etc.

* flexi_class_alter tries to minimize actual amount of database updates by preserving current object values whenever
possible. For example, changing property type typically does not involve updates of existing data. Flexilite only scans existing data for
 compatibility, and depending on function arguments, may either ignore found incompatibilities, correct them, or fail entire operation.

* flexi_prop_create, flexi_prop_alter and flexi_prop_drop are convenient shortcuts for flexi_class_alter, to deal with one property at a time.

* When a new property is added, only class definition is updated. If a new property has default value defined, future read operations will
 return that default value as it would exist in database

* When property is deleted and no force flag is set, only class definition is updated. No actual data get updated, but future read and update
operation will ignore deleted property.

* Many types of property modification do not require data updates. For example, changing property type from Number, Integer or Boolean to Text
will preserve existing values to stay as is, but during future read and update operations, values will be converted to text representation.

* Classes are exposed as SQLite virtual tables (USING flexi).For plain tabular data with scalar properties this is sufficient for all standard
database operations. Select, insert, update, delete requests can be executed in a normal SQL-like way.

* Real beauty of Flexilite starts when plain tabular old-school RDBMS schema needs to be extended to something more sophisticated.
These types of extensions include: a) relations between objects, including one-to-one, one-to-many, many-to-many, and nested objects;
b) polymorphic collections, when objects of different classes are presented in one collection, c) mixing different types in one property

