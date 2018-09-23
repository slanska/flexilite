**This project is at early development phase!**

Developed with JetBrains tools:

[![CLion icon](./logo/icon_CLion.png "CLion" )](https://www.jetbrains.com/clion/?fromMenu)

# flexilite

> "Smart data structures and dumb code works a lot better than the other way around." 
> 
> Eric S. Raymond, The Cathedral and The Bazaar.

> "Bad programmers worry about the code. Good programmers worry about data structures and their relationships."
> Linus Torvalds

#What is Flexilite?
Flexilite (**"F"**) is a SQLite extension library, written in C/C++ and LuaJIT, which converts ordinary SQLite database
into repository of data classes, objects and their relations, with highly dynamic and flexible structure. 
Flexilite intends to solve typical problems of evolutional design of relational databases. "F" covers most of known 
db schema refactoring patterns. Not only that, "F" also provides few useful and highly demanded features out of box. 
We will list them later in this document.

**Loading in any SQLite app:**
```sqlite 
select load_extension('libFlexilite');
```

###Main idea in few sentences:
Traditional way to design db schema becomes noticeably outdated in the modern ever-changing world. What was good 
30 years ago (RDBMS) does not match real life complexity nowadays. 
When designing new system or maintaining existing one, 
db schema has to go through many iterations of refactoring.

The goal of this project is to provide proof of concept and at the same time production ready, easy-to-use, 
feature rich and flexible solution to deal with uncertainties of database schema design.
Flexilite is based on SQLite as a storage engine and thus is usable in any type of application where SQLite 
is a good fit (from embedded systems, to smartphones, to desktop apps, to small-to-medium websites).

We strive to provide ability to organize, store and query data in the most flexible but still structured way. The goal of "F" is
to be able to import arbitrary XML file, without necessity to define classes and properties, and create ad-hoc classes during 
import. Then, be able to migrate data into a meaningful schema, using set of available data refactor patterns. At the end, to convert
raw schemaless data into structured object graph, with strict (or not so strict) rules and schema. 

###Install and Build
[Build instructions](doc/HowToBuild.md)

### Feature Highlights

* Implements advanced version of EAV/CR (Entity-Attribute-Value/Class-Relation) model 
* Stores all data and metadata in the fixed set of tables (about a dozen)
* Provides object oriented design, similar to what C++/Java/C#/Python etc. have, i.e. classes, properties and methods
* Has wide range of schema enforcement - from ad-hoc classes created from imported data, to strictly enforced schema with
validation rules. And schemaless or semi-schema or anything else in between
* Offers natural, easy and efficient way to modify schema, following go-with-the-flow approach. Practically any kind of schema 
or data refactoring pattern is available. You can start from very preliminary schema or no schema at all, and then adjust it
according to changing business requirements, or simply follow with the process of understanding of real life use cases
* Efficiently utilizes all major features of SQLite: JSON, full text search, RTREE, CTE, dynamic typings, filtered indexes etc.
* Designed to support medium size databases (e.g. 10 GB and 10 mln objects)
* Written (mostly) in LuaJIT
* Provides query language based on Lua
* Provides scripting language (Lua) to write custom triggers, functions and formulas
* Implements fine granular access rules, based on class, property and object level
* Cross platform - can compile and run on Windows, Mac and Linux. iOS and Android are coming
* Classes are similar to tables in ordinary RDBMS tables: with plain list of scalar typed columns (properties in "F" terminology)
* Supports indexes on any property 
* Supports full text search index on any text property 
* Tracks all changes in metadata and data (enabled by default) for full traceability
* Can convert scalar column or group columns to array, or extract it to a separate table
* Import and export data in XML, JSON, Yaml, CSV format
* Can convert existing RDBMS databases into Flexilite format (using Flexish_cli utility)
* Supports computed properties
* Supports database-within-database concept (TODO - details in the separate document)
* Optionally allows end-user to extend schema and define their own properties or even classes

## Still not sure? Here is an example

Let's take a look at this hypothetical flow of database schema migration:
1) Create DB table Person, with columns: PersonID, Name, Email, Phone, AddressLine1, AddressLine2, City, 
ProvinceOrState, PostalCode, Country
2) On next iteration, added columns WorkEmail, WorkPhone and renamed Email to PersonalEmail, Phone - to CellPhone
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

Sounds familiar? Have you ever needed to deal with cases like those above?
Do you remember how painful every step was?
Needless to mention that every step from this list would normally require:
a) writing script to migrate database schema
b) writing script to move existing data (or reset existing database and start from fresh new, if change happens in the
middle of development and data are not worthy to keep).

(We omit here other things that also need to be done after DB schema changes - updating UI forms, and very likely, 
revisiting UI flow, changing navigation, handling different typical cases and so on.
These tasks can be as time and effort consuming as direct DB changes, but we will ignore this class of changes as it goes too far
from the library scope).

### Data schema evolution patterns
We have went through this pain as well, and eventually come up with the concept of data schema evolution patterns.
We analyzed typical practical cases and came up with the list of data schema evolution patterns. Every pattern involves 
specific modification of schema and existing data. Sequence of such patterned modifications step allow to migrate from one schema to 
a completely different one, while preserving data and keeping it in a consistent state.

In major percentage of cases database schema in its evolution shifts towards complication, and decomposition. 
I.e. schema requires new tables/classes to be introduced, new columns/attributes. 

Database schema migration patterns described above present just a subset of typical issues that database and application
developer needs to address when designing, developing and maintaining real world business software.
   
Besides, there is whole set of other data related tasks that are not covered by a traditional RDBMS (or NoSQL) systems, and
require case-by-case resolving. Short list of such tasks might look as follows:
- 1) many-to-many relations. In RDBMS world, there is no out-of-box way to implement this. Usually this kind of relation is handled by adding special table 
which would hold IDs for both related tables.
- 2) re-ordering items in the list. While this type of functionality is completely ignored by RDBMS concept, it is rather 
popular requirement/nice-to-have features in the real world application. Again, like #1, if required, this feature needs to be
dealt with case-by-case basis.
- 3) polymorphic collections, when a collection can hold items of different types ("classes"")
While different structures can be handled during loading phase via transformation, handling extra data (if needed to preserve) 
require either adding generic field (JSON, BLOB or memo), or extending schema with one or more additional tables/collections to store these data.
- 4) user-defined-fields(or attributes), i.e. providing ability for the end user (non programmer) to extend db schema with his/her own data.
Having this feature supported would require additional efforts from developers team to preserve this data during application
upgrade and their own database schema changes.
- 5) sort of special case for #4 - ability for the end user (normally, in 'Database Manager' role) to define new data classes
and give 'Data Entry' users to extend individual objects with these custom classes (compose mixin objects). Typical example is online store
with products categorized into many groups and sub-groups, with their own attributes (e.g. TV Sets and GPS both have ScreenSize 
attribute, but belong to different product groups).
- 6) Multi-language support for database metadata (class and attribute names), including input field labels, column titles, descriptions,
hints, tool tips, place holder texts etc.
- 7) *Enum* support. Almost every master table (like Person, Product, Order etc.) has one or more enumerated fields (for status, category and so on). 
Definitions of these enum attributes vary from fixed lists of 2-3 items to user extendable lists of dozens or even hundreds elements.
Total number of such enums in the real life database can easily reach hundreds. Handling this can be challenging as developers need to 
make decision on how to design and manage these definitions. Possible solutions usually include one of those: a) hard coded constraints 
directly in table definition, b) creating whole bunch of tiny separate tables, 1 table per enum and 1 row per enum item, 
c) creating one table for all enums, with 
additional column (something like 'EnumType'). Also, proper handling of enums might require support for multi-language representation of items to
the user. Implementation of such requirements, coupled together with necessity to translate table/column metadata, tend to lead to cumbersome, complicated 
design. As for me, this kind of work always makes me feel that I had to re-invent the wheel again and again.
- 8) Adding full text search for some text fields. Needs to be handled on case-by-case basis, by implementing individual indexes. 
Ability to do search for text values in the scope of entire database or subset of certain fields requires non-trivial design and significant implementation
efforts.
- 9) Change tracking, i.e. ability to keep history of changes for certain classes/tables. 
- 10) Add time-serie support, i.e. ability to keep time-based state for simple objects or their subsets 
(this task is somehow related tp #9). Examples:
current rates, employee salary history, tracking fleet and other assets and so on.
   
## (Incomplete )List of schema refactoring patterns
-Extract 1 or more fields from existing table to a new table (or merge to existing one) and convert it to reference (with name)
-Change reference type from 1-to-1 to 1 -> many, or many -> many
-Add property
-Remove (or hide) property
-Change property type and other attributes (unique, required, length, UI editor type/viewer etc.)
-Merge 2 classes, with optional property mapping
-Move existing object(s) from one class to another (new or existing)
-Set property as indexed (for fast lookup) or full text indexed
-Move referenced item in the list up and down
-Rename class
-Rename property
-Change class and property settings
 
## How does Flexilite work?
In order to make schema refactoring smooth, flexible and fast, Flexilite utilizes special database design. 
In fact, this design is based on Entity-Attribute-Value (EAV) concept, with some improvements to 
avoid performance degradation associated with traditional EAV implementation.
All actual data is stored in the fixed set of tables. 

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
We focus currently on SQLite and also have plans towards supporting BerkeleyDB, via SQLite API, for better writing
concurrency, replication and high availability.

## Running tests

```shell
cd  ./test_lua
busted --lua=PATH_TO_LUJIT_EXE ./index.lua 
```

For example:
```shell 
/torch/luajit/bin/busted --lua=/torch/luajit/bin/luajit  ./create_class.lua 
```

(**Note that busted needs to run using LuaJit interpreter. POC Lua will fail**)

