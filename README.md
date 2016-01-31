# flexilite
node.js library for SQLite-based flexible data schema. Combines entity-attribute-value and pre-allocated table columns. 
The goal of this project is to provide easy-to-use, feature rich and flexible solution to deal with uncertainties 
of database schema design.
Flexilite is based on SQLite as a storage engine and thus is usable in any type of application where SQLite 
is a good fit.
The main idea of Flexilite is to provide API to deal with database schema in an evolutional and easy way.

## Short introduction

Here is a very brief demonstration of Flexilite concept. Structure of tables below are trimmed for 
the sake of this example. 

###Table .attributes
Holds key-value pairs for all semantical attribute names registered in the system
These attributes include class names and property names.
Note that name case does not matter: semantically, from the point of Flexilite - Person == person, Age == age

|-|-|
| AttributeID | Name | PluralName |
| 1 | Person | Persons |
| 2 | Company | *NULL*|
| ... | ... |
| 11 | Name | *NULL*|
| 12 | Age | *NULL*|
| 13 | Salary |*NULL*|

###Table [.classes]
Lists all classes in database. Class is equivalent of table definition in the traditional
RDBMS. Column *'Properties'* holds JSON string with list of class properties.

|---------|-----------------|------------|
| ClassID | CurrentSchemaID | Properties |
|1          |22              |```{ name: {id: 11, title: "Name"}, age: {id: 12, title: "Age"}, salary: {id: 13, title: "Salary"}}```|
|2  |

###Table [.schemas]

Collection of all data schemas in the database. Every class may be associated with multiple schemas.
One schema from the associated list is current class' schema. Schema defines, in particular, 
a) class properties mapping and b) validation rules

|-|-|-|
| ClassID | SchemasID | Data |
|1|21|```{11: {jsonPath: ".name"}, 12: {jsonPath: ".age"}, 13: {jsonPath: ".salary"}}```|
|1|22|```{11: {jsonPath: ".name"}, 12: {jsonPath: ".age"}, 13: {jsonPath: ".privateInfo.salary"}}```|

###Table [.objects]

All data items (AKA objects AKA rows AKA records) in Flexilite are stored in one table. Every object has unique ID 
(autoincrement integer), class ID and schema ID. Actual data is stored in *'Data'* column
as JSON. Schema ID associated with a given object determines how actual property values
can be retrieved.

|-|-|-|-|-|
|ClassID | SchemaID | ObjectID | HostID | Data |
|1|21|101|```null```|```{name: "John Doe", age: "31", salary: "30000"}```|
|1|22|102|```null```|```{name: "Andrew Fullton", age: "46", privateInfo: { salary: "65000" }}```|

In the data snapshot above there are 2 objects which belong to the class *Person* and are assigned
to different schemas (21 and 22). *Data* field has JSON values of different structure, 
corresponding to associated schemas. 

###Views for class

For every class registered in the system Flexilite maintains 2 views. These views are named
according to class name (to be exact, according to the optional plural name). So,
for *Person* class it would be the following views defined (let's assume that class *Person*
has plural name defined as *Persons*):
- [Persons]
- [.Persons.]

Both these views are updatable, i.e. then can be used not only for fetching data, but also
for standard CRUD operations.

###View [Person]

Think about this view as a canonical table in the relational database. You can execute
SELECT as well as INSERT, UPDATE and DELETE statements. All properties defined for the
corresponding class are represented as view columns. Definition of this view is generated automatically
by Flexilite on class or schema change.

In a bit simplified way, definition of *Person* view will look as follows:

```
create view if not exists [Persons] as 
select
(json_extract(o.Data, json_extract(s.Data, '$."11".jsonPath'))) as Name,
(json_extract(o.Data, json_extract(s.Data, '$."12".jsonPath'))) as Age,
(json_extract(o.Data, json_extract(s.Data, '$."13".jsonPath'))) as Salary
from [.objects] o join [.schemas] s on o.SchemaID = s.SchemaID where o.ClassID = 1;
```



## Why Flexilite?
Typical cycle of relational database design can be described in the following steps:
1) Collect requirements, make preliminary database design.
2) Implement foreign key and other constraints
3) Take care of many-to-many relations but creating a special table.
4) Work through multiple iterations of schema changes, which include:
- adding/removing/renaming/changing columns
- adding new tables, renaming existing ones
- maintaining necessary indexes and miscellaneous constraints
- adding support for logging changes, when needed (for example, to meet SOX requirements). For every table, every column
- adding support for full text search. Again, individually, per table and column

5) In real life, database refactoring can be much more complicated. For example:
- splitting table to 2 or more tables. Example: you created table called Customers, with Phone column. At some point you realize that customer may have multiple phones, so you need to a) create a new table, called CustomerPhones, b) extract existing Phone data from Customers to CustomerPhones, c) setup foreign key relation.
- then you need to do similar job for Employees table, Suppliers table etc.
- then you decide to combine all common data from Customers, Employees and Suppliers table into a new table, called Persons or Entities. And you need to go through the same boring, error-prone, routine procedure again.
 
Database schema design is similar to constructing class model in object-oriented library. With one fundamental difference - all this refactoring has to be applied on existing production data in the field. With all risks to loose or corrupt real customer previous data.

These are just few examples of schema refactoring that a database developer needs to cope with. Beside refactoring, there is a whole class of typical data manipulations that are not handled by canonical RDBM systems (like re-order items in the order detail list, for instance).

But it is not just data refactoring from a developer standpoint.

What if your end-users need to have some flexibility of defining their own schema changes? Adding new columns? New tables? Maybe. even moving data from one table to another? 
How about maintaining user defined list of columns depending on, e.g. product category? 'Laptops' category should have column 'RAM', but category 'TV sets' does not need it. ANd both need attribute 'Screen size'.

What if end user needs to store data in flexible way, without sticking to a hard data schema? This is what NoSQL databases were initially designed for. To store arbitrary objects, or "documents". What it you want to provide semi-flexible capabilities when part of your table schema is defined by developer and fixed, but user still can extend it with... well, pretty much anything?

Flexilite can help you as a developer to deal with both major cases mentioned above:
- make database schema evolution process for developer as easy as possible
- provide set of functions for typical database operations
- allow end-users make their own changes in database schema.
 
## Features of Flexilite
- create tables similar to ordinary RDBMS tables: with plain list of scalar typed columns
- define indexes on those columns (single column indeces only)
- define full text search indexes on any column and do full text search
- enable tracking all changes (enabled by default) for full traceability
- convert scalar column or group columns to array, or extract it to a separate table
- create columns with special types: geospatial, for example, with ability to perform efficient lookup on these columns using reversed indexes
- related data (like order and its details) may be grouped together and stored physically in the same area of data file. Such data can be retrieved all in the single request reducing loading time   
- role based access rules, table-, row- and column-level  
- import documents in XML, JSON, Yaml, CSV format
- convert existing RDBMS databases into Flexilite format
 
## Schema refactoring patterns
-Extract 1 or more fields from existing table to a new table (or merge to existing one) and convert it to reference (with name)
-Change reference type from 1-to-1 to 1 -> many
-Add column
-Remove (or hide) column
-Change column type and other properties (unique, required, length, editor/viewer etc.)
-Change column association (property type)
-Merge 2 tables, with optional field mapping
-Move existing record(s) from one table to another (new or existing)
-Set column as indexed (for fast lookup) or full text indexed
-Change column storage mode (fixed for fast load or lazy-load)
-Move referenced item in the list up and down
-Rename class
-Rename property
-Change class and property settings
 
## How does Flexilite work?
In order to make schema refactoring smooth, flexible and fast, Flexilite utilizes special database design. 
In fact, this design is based on Entity-Attribute-Value (EAV) concept, with some improvements to 
avoid performance degradaion associated with traditional EAV implementation.
All actual data is stored in the fixed set of tables. 

####Objects
This table holds 1 row per custom table row. Custom table is indicated by ClassID field. ObjectID (8 byte integer) consists of 2 pieces and is defined by the formula: (HostID << 31) | AutoID (<auto-incremented-ID>). HostID is an AutoID of another object ID, which in this case becomes master (or host) object. 

Example:
Order has HostID = 2 and AutoID = 2, so ObjectID = 4294967298 (so this is a self-hosted object). Nested Order Detail will have HostID = 2, and AutoID = 3, thus giving ObjectID = 4294967298. Since ObjectID is a primary key for table Objects, Order abd OrderDetail rows will be stored together and can be loaded at once.

Maximum object AutoID is (1 << 31) - 1.

There are 16 data columns, named A to P. They are used for 'fixed' mapping to the custom table columns. In this case, there is no any performance penalty comparing to traditional relational table design, but there is a small storage penalty as if not used, every data column takes 1 byte of file storage. 

[ctlo] column. This is control object attribute that holds information about indexing, full text and range search  

####Values
This table is detail table to Objects, it is related to the latter by ObjectID. It implements canocial Entity-Attribute-Value model, via ObjectID, PropertyID and Value columns. Plus it extends EAV model with support of arrays (via PropertyIndex column) and references to other objects (special type of value).

[ctlv] column is a value control attribute, it holds settings for role of value (reference, scalar etc.), indexing, full text and range search configuration (similar to Objects.[ctol]). 

##How data are stored?
I am a big fun of micro optimization, even though this approach has been criticized a lot. In scope of Flexilite 
micro-optimization means that every possible option is used to provide the best performance.
These options are following:
**WITHOUT ROWID indexes.** This SQLite feature allows to store related rows _physically_ adjacent to each other. It means
that value records for the same entity will most likely be stored on the same page (or 2 adjacent pages, in the worse scenario).
 It also means related entities, if their IDs are assigned in a special way, can be also stored _physically_ together. 
 What it gives at the end? It gives possibility to load all values for the given entity and also all related entities with 
 all their values in one SQL query.
 
**Partial indexes** allow selective indexting of specific attributes for the fast lookup. Indexing is controlled 
by bit masks.
  
**For data with schema** Flexilite creates and maintains updatable _views_. These views serve purpose of regular tables and allow 
transparent access to data, identical to normal SQL queries.

Here is an example of such a view:

```
create view if not exists Orders as
 select o.A as OrderID,
 o.B as CustomerID, 
 o.C as OrderDate,
 (select Value from v where PropertyID = 123 and PropIndex = 0) as CommentLine1
 from Objects o, (select * from Values vv where vv.ObjectID = o.ObjectID) v
```



##Is it alternative to NoSQL?

Short answer - yes and no. Long answer: Flexilite can definitely be used as a document oriented database (**"yes"**), 
but its approach and underlying database engine serve different purpose. It is not designed to replace big guys like Mongo
or PostgreSQL (**"no"**). It is good fit for small to medium size database. And unlike well known NoSQL databases,
SQLite supports metadata natively. It means that it combines schema and schemaless types of storage.
 

## Why SQLite?
SQLite is widely used - from smartphones, to moderately used websites, from embedded devices, 
to rich desktop applications. It is reliable, fast and fun to use. 
And most importantly, SQLite has all features needed for achieving of Flexilite goals. 
When properly configured, SQLite can be a perfect database storage for small workgroups (8-10 simultaneous users 
creating new content). By proper configuration we mean: use larger page sizes (8KB is default for Flexilite),
use memory for temporary storage, use WAL for journaling mode, and use shared cache. Optimal configuration will be 
covered in a separate article.

## Are other databases supported?
Currently it is SQLite only. We also have plans and ideas about implementing Flexilite on PostgreSQL.
