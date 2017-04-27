**This project is at early development phase!**

Developed with JetBrains tools:
[![CLion icon](./logo/icon_CLion.png "CLion")](https://www.jetbrains.com/clion/?fromMenu)

# flexilite

> "Smart data structures and dumb code works a lot better than the other way around." 
> 
> Eric S. Raymond, The Cathedral and The Bazaar.

> "Bad programmers worry about the code. Good programmers worry about data structures and their relationships."
> Linus Torvalds

#What is Flexilite?
Flexilite ("F") is a C library which converts ordinary SQLite database
into repository of data classes, objects 
and their relations, with highly dynamic and flexible structure. Flexilite intends to solve typical problems of 
evolutional design of relational databases. "F" covers most of known db schema refactoring patterns. Not only that,
"F" also provides few useful and highly demanded features out of box. We will list them later in this document.

*Main idea*
In few sentences:
Traditional way to design db schema becomes noticeably outdated in the modern ever-changing world. What was good 
30 years ago (RDBMS) does not match real life complexity nowadays. 
When designing new system or maintaining existing one, 
db schema has to go through many iterations of refactoring.

The goal of this project is to provide proof of concept and at the same time production ready, easy-to-use, 
feature rich and flexible solution to deal with uncertainties of database schema design.
Flexilite is based on SQLite as a storage engine and thus is usable in any type of application where SQLite 
is a good fit (from embedded systems, to smartphones, to desktop apps, to small-to-medium websites).

## Short introduction

Here is a very brief demonstration of Flexilite concept and what sort of problems it is designed to solve.
 
Typical scenario of database design and ongoing maintenance may be 
demonstrated in the following list of schema iterations:
1) Create DB table Person, with columns: PersonID, Name, Email, Phone, AddressLine1, AddressLine2, City, 
ProvinceOrState, PostalCode, Country
2) Added columns WorkEmail, WorkPhone and renamed Email to PersonalEmail, Phone - to CellPhone
3) Create table Phones, with columns: PhoneNumber, PersonID, PhoneType 
moved value from Phone column in Person table, with assigning PersonID. (setup one-to-many relation)
4) Do the same for Email column, by creating table called Email, with columns: PersonID, Email, EmailType.
5) For maintaining database integrity create tables EmailType and PhoneType
6) In table Person create columns FirstName and LastName, split value of Person.Name into these 2
new columns, drop column Name, created computed column Name = FirstName + ' ' + LastName
7) Create table Address, with columns AddressID, AddressLine1, AddressLine2, City, ProvinceOrState, PostalCode, Country
8) Move address info from Person table to Address table, add column AddressID, set it
to ID of newly associated Address row, at the end dropped address columns from 
Person table
9) Create table CountryID, with columns CountryCode, CountryName
10) Extracted country data from table Address, replacing Country with CountryCode. Also, apply fuzzy logic
to process possible misspelling of country names

Needless to mention that every step from this list would normally require:
a) writing script to migrate database schema
b) writing script to move existing data (or reset existing database and start from fresh new, if change happens in the
middle of development and data are not worthy to keep).

(We omit here other things that also need to be done after DB schema changes - updating UI forms, and very likely, 
revisiting UI flow, changing navigation, handling different typical cases and so on.
These tasks can be as time and effort consuming as direct DB changes, but we will ignore this class of changes as it goes too far
from the scope).

In major percentage of cases database schema in its evolution shifts towards complication, and decomposition. 
I.e. schema requires new tables/classes to be introduced, new columns/attributes. 

Database schema migration patterns described above present just a subset of typical issues that database and application
developer needs to address when designing, developing and maintaining real world business software.
   
Besides, there is whole set of other data related tasks that are not covered by a traditional RDBMS (or NoSQL) systems, and
require case-by-case resolving. Short list of such tasks might look as follows:
1) many-to-many relations. In RDBMS world, there is no out-of-box way to implement this. Usually this kind of relation is handled by adding special table 
which would hold IDs for both related tables.
2) re-ordering items in the list. While this type of functionality is completely ignored by RDBMS concept, it is rather 
popular requirement/nice-to-have features in the real world application. Again, like #1, if required, this feature needs to be
dealt with case-by-case basis.
3) data to the same collection/table/class is collected from various sources with a (likely) different 
structure and a (possibly) extra data, 
which is not included into original schema.
While different structures can be handled during loading phase via transformation, handling extra data (if needed to preserve) 
require either adding generic field (JSON, BLOB or memo), or extending schema with one or more additional tables/collections to store these data.
4) user-defined-fields(or attributes), i.e. providing ability for the end user (non programmer) to extend db schema with his/her own data.
Having this feature supported would require additional efforts from developers team to preserve this data during application
upgrade and their own database schema changes.
5) sort of special case for #4 - ability for the end user (normally, in 'Database Manager' role) to define new data classes
and give 'Data Entry' users to extend individual objects with these custom classes (compose mixin objects). Typical example is online store
with products categorized into many groups and sub-groups, with their own attributes (e.g. TV Sets and GPS both have ScreenSize 
attribute, but belong to different product groups).
     
6) Multi-language support for database metadata (class and attribute names), including input field labels, column titles, descriptions,
hints, tool tips, place holder texts etc.

7) *Enum* support. Almost every master table (like Person, Product, Order etc.) has one or more enumerated fields (for status, category and so on). 
Definitions of these enum attributes vary from fixed lists of 2-3 items to user extendable lists of dozens or even hundreds elements.
Total number of such enums in the real life database can easily reach hundreds. Handling this can be challenging as developers need to 
make decision on how to design and manage these definitions. Possible solutions usually include one of those: a) hard coded constraints 
directly in table definition, b) creating whole bunch of tiny separate tables, 1 table per enum and 1 row per enum item, 
c) creating one table for all enums, with 
additional column (something like 'EnumType'). Also, proper handling of enums might require support for multi-language representation of items to
the user. Implementation of such requirements, coupled together with necessity to translate table/column metadata, tend to lead to cumbersome, complicated 
design. As for me, this kind of work always makes me feel that I had to re-invent the wheel again and again.

8) Adding full text search for some text fields. Needs to be handled on case-by-case basis, by implementing individual indexes. 
Ability to do search for text values in the scope of entire database or subset of certain fields requires non-trivial design and significant implementation
efforts.

9) Change tracking, i.e. ability to keep history of changes for certain classes/tables. 
10) Add time-serie support, i.e. ability to keep time-based state for simple objects or their subsets 
(this task is somehow related tp #9). Examples:
current rates, employee salary history, tracking fleet and other assets and so on.
    
## How Flexilite can help?
In order to help with the challenhes listed above, "F" introduces simple and clean concept. 
It is based on SQLite capabilities and features, so that 
implementation of "F" is compact, light and efficient. "F" utilizes the following SQLite features:
- type affinity (any cell in the table may have value of any data type)
- updatable views, which can be used as replacement for physical tables with help of INSTEAD OF triggers
- recently added support for JSON data type and manipulation based on JSON path
- clustered (i.e. WITHOUT ROWID) indexes
- triggers
- common table expressions
- full text search
- R-trees

Basic concept of "F":
- All data and metadata are stored in the fixed number of physical tables (< 10 tables).
- "F" provides out-of-box solutions for typical patterns of database schema evolution as well as general database features (listed above).
- "F" heavily uses JSON for processing semi-structured data, for both metadata and records.
    
 
Structure of tables below has been trimmed for 
the sake of clarity. 

### Table .names
Holds key-value pairs for all semantical names registered in the system
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

Note that actual structure of .attributes table includes few other columns, which store, in particular, translation information for 
multi-language support.
Purpose of this table is to define set of semantic attributes for the entire database. Every semantic attribute has its singular name,
plural name, ID and mult-language metadata. Attribute IDs are used throwout the database, for classes, their properties, enum types,
enum items etc.

###Table [.classes]
Lists all classes in database. Class is equivalent of table definition in the traditional
RDBMS. Column *'Properties'* holds JSON string with list of class properties.

|---------|-----------------|------------|
| ClassID | CurrentSchemaID | Properties |
|1          |22              |```{ name: {id: 11, title: "Name"}, age: {id: 12, title: "Age"}, salary: {id: 13, title: "Salary"}}```|
|2  |

Every class has ID (foreign key to .attributes.ID), name (alias to attribute name), and collection of properties.
Properties can be:
* primitive (integer, string, boolean)
* collection of primitive (string[])
- dependent object (owned and deleted by master object)
- collection of dependent objects
-reference to independent object
- collection of references


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
SELECT as well as INSERT, UPDATE and DELETE statements on this view, so at this point it would
be absolutely identical to a real table. All properties defined for the
corresponding class are represented as view columns. Definition of this view is generated automatically
by Flexilite on class or schema change.

In a bit simplified way, definition of *Person* view will look as follows:

```sql
create view if not exists [Persons] as 
select
(json_extract(o.Data, json_extract(s.Data, '$.11.jsonPath'))) as Name,
(json_extract(o.Data, json_extract(s.Data, '$.12.jsonPath'))) as Age,
(json_extract(o.Data, json_extract(s.Data, '$.13.jsonPath'))) as Salary
from [.objects] o join [.schemas] s on o.SchemaID = s.SchemaID where o.ClassID = 1;
```

###Table .ref-values
This table os mostly used for storing references between objects. 

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
- define indexes on those columns (single column indexes only)
- define full text search indexes on any column 
- enable tracking of all changes (enabled by default) for full traceability
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

```sql
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
to rich desktop applications. It is reliable, fast, cross-platform and fun to use. 
And most importantly, SQLite has all features needed for achieving Flexilite goals. 
When properly configured, SQLite can be a perfect database storage for small workgroups (8-10 simultaneous users 
creating new content). By proper configuration we mean: use larger page sizes (8KB is default for Flexilite),
memory for temporary storage, WAL for journaling mode, use shared cache
and connection pooling. Optimal configuration will be 
covered in a separate article.

## Are other databases supported?
Currently it is SQLite only. We also have plans and ideas about implementing Flexilite on PostgreSQL.
