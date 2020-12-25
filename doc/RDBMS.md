### What is wrong with RDBMS?

Concept of Relational Database Management Systems (RDBMS) was introduced in
1970s, in the era of quite expensive, low capacity storage,
with certain restrictions on how to access data. Core element
of RDBMS is the _record_ - sequence of bytes of fixed size, mapped to _structure_.
Structure is defined set of fields of various types, with known size in bytes and offset from
structure beginning. At that time it was the only possible way to describe big collections
of data. This idea was so dominating that even many languages designed in that period provided
file access API as set of routines to get Nth record in the file (Pascal, for example).

The same field has exactly the same type and same size in all records. 

Revolutionary concept of relational database was based on fact that every record has its own unique
ID and fields in other records can be served as _pointers_, i.e. can reference other records. Relational
database become dominant in the database world, pushing away alternatives like graph databases (direct
reference by pointer rather than by ID) and others.

Modern RDBMS systems went far away from initial idea, but fundamentally record as collection of same type-same 
size fields is still prevalent. For years of programming I witnessed many cases of raising and falling
various object-oriented frameworks, database wrappers etc. 
All these frameworks were created with the intention to struggle
with limitations of RDBMS concept and suggest better approach, which would be more adequate for
real life cases.

Here is my list of shortcomings and limitations of RDBMS, which are typically become area for
huge time and effort spending (in no specific order):

#### 1. Enums
 
RDBMS does not provide native support for enumerated values, i.e. application domain specific
lists of predefined constants. This is typically resolved with:

- define enumerations on application level only, and simply store values in database. Enumerations
just do not exist in scope of database

- create separate (normally tiny) tables for every enumeration type. In serious applications number of such tiny tables
may reach hundreds, with all respective maintenance burden including but not limited
to referential integrity, UI forms etc.
 
- create few (or just one) tables to keep all enum items, with special field - EnumType, and custom implementation
of referential integrity  
    
At some point, sooner or later, growing application needs to support multiple languages. 
It would require to have those enum items translated too. Resulting table structure, in such advanced version,
 would like this:

|EnumType|ID|Culture|Text|OrdinalPosition  

Also, some enumerations are subject to be extended by end-user. Which lead again, to extra complexity and
custom implementation, usually, individually for evert enumeration type. 
Finally, when doing search, it is often needed to include actual text values into search, within selected language.

For any real application just enum support means hundreds of development and testing hours.

#### 2. Lists (aka Arrays aka Vectors)

Standard RDBMS do not support value list (aka arrays aka vectors). So, if requirement is to have, say,
multiple tags per record (kind of extended enums) or just few email addresses or few phone numbers, 
additional table needs to created. Which brings us to the next section.

#### Many-to-many relation

Standard RDBMS were designed to support one-to-many or one-to-one relations (and even this area is really half cooked, as 
we will cover in the next section). Many-to-many relation needs one more table to create and maintain, thus 
cluttering database schema with redundant tables.

#### Half defined relations

Despite of "R" char in **RDBMS**, _relations_ are actually half cooked in RDBMS. Even though relations are defined via foreign key,
so they are generally known to the database, this knowledge adds very little to real usage - one needs
to apply knowledge of the definition every time when 2 tables have to be joined together. This is unnecessary complication.

#### User defined fields

In many systems there is requirement to allow end users (or end-user admins) to extend tables with custom fields 
without alteration database schema. This requirement normally leads to developing some in-house Entity-Attribute-Value
design (often even without realizing name of concept) or reserve additional fields or have additional 
JSON/XML/memo column to keep these custom data. Integrating those _extra_ fields into CRUD flow involves
a lot of development and testing effort.

#### Sparse columns

Medical, scientific, manufacturing and other types of databases often deal with sparse columns, where 
any given record has only small fraction of non-null values. Table may need thousands fields to be defined
and only dozens of them would be actually used for any given record. Even though 
to accomplish this requirement many databases offer special features (like sparse columns in MS SQL), it is not part 
of SQL ANSI standard and implementation is often sub-optimal from performance standpoint or limited in features.

#### Polymorphic collections

Records in RDBMS must follow the same structure, standard approach does not support having different types of records in the same collection,
which is typical requirement in real life scenarios. To accomplish this, developers invent custom schema, like 1:1 tables.
Though, some databases have support for table inheritance (PostgreSQL, as a example), this feature is not 
standard.
 
#### Ordinal position in collection

Sometimes records in collection should be presented in certain order. To accomplish this, special measures
should be done, with adding a new column ("OrdinalPosition"), and have application logic to allow re-ordering. Normally it gets
implemented in non generic way, per individual table basis.

#### Documents or nested records

In real life cases object are naturally formed in hierarchy (and this was one of major reason of 
introducing NoSQL databases few years ago). RDBMS deal with plain records only. 
Custom application logic would be needed to transform plain lists of records into hierarchical structure,
which is better suited for real business cases. Every case turns to be overcomplicated, custom, error prone implementation.
Implementing even simple case with one master and few nested objects leads to having at least 3 additional tables in database - one 
for master, one for nested data, and one for many-to-many relation.   

#### Multi-tenancy or "Databases within databases"

In special cases there is a need to keep sort of databases-within-database. Here are the examples:
    - alarm system monitoring company, maintaining many accounts with various types of individually 
    configured alarm systems. So, there is a 'primary' database with customers, accounts etc. and specific equipment configuration
    which also needs to be structured like normal database and operated as such.
    - equipment vendor, with customer account database, and individual configuration for every piece
    of equipment. 
    
Accomplishing this kind of requirements usually end in custom EAV or similar solution.

#### Full text search: implementation and integration

At some point during application lifecycle and database size growth need in efficient fuzzy text search arises.
This part is not standardized in ANSI SQL, and requires a good portion of design, implementation, testing
and application adjustment. It becomes even more cumbersome for large existing and already deployed applications.

#### Metadata

Many applications utilize some sort of automatically generated UI, based on database structure and constraints.
Standard RDBMS do not have support for custom meta data, associated with tables and columns.

#### Schema migration

Database schema goes through evolution together with growing business needs and changing vision of business analysts,
stockholders, developers and customers.
Because of strict design of RDBMS schema evolution becomes tedious and unnecessary complicated process
of preparing scripts for schema change, scripts for data migration, intermediate backup and restore actions,
additional testing and a lot of changes in application code. 
