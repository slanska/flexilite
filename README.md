# flexilite
node.js library for SQLite-based flexible data schema. Combines entity-attribute-value and pre-allocated table columns. 
The goal of this project is to provide easy-to-use, feature rich and flexible solution to deal with uncertainties of database schema design.
Flexilite is based on SQLite as a storage engine and thus is usable in any type of application where SQLite is a good fit.
The main idea of Flexilite is to provide API to deal with database schema in an evolutional and easy way.

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

5) And this is just a short list of typical changes required to handle evolution of database schema. In real life, database refactoring can be much more complicated. For example:
- splitting table to 2 or more tables. Example: you created table called Customers, with Phone column. At some point you realize that customer may have multiple phones, so you need to a) create a new tables, called CustomerPhones, b) extract existing Phone data from Customers to CustomerPhones, c) setup foreign key relation.
- then you need to do similar job for Employees table, Suppliers table etc.
- then you decide to combine all common data from Customers, Employees and Suppliers table into a new table, called Persons or Entities. And you need to go through the same boring, error-prone, routine procedure again.
 
These are just few examples of schema refactoring that a database developer needs to cope with.
Database schema design is similar to constructing class model in object-oriented library. With one fundamental difference - you are often required to apply all this refactoring on existing production data in the field. With all risks to loose or corrupt real customer previous data.

But it is not just data refactoring from a developer standpoint.

What if your end-users need to have some flexibility of defining their own schema changes? Adding new columns? New tables? Maybe. even moving data from one table to another? 
How about maintaining user defined list of columns depending on, e.g. product category? 'Laptops' category should have column 'RAM', but category 'TV sets' does not need it. ANd both need attribute 'Screen size'.

What if end user needs to store data in flexible way, without sticking to a hard data schema? This is what NoSQL databases were initially designed for. To store arbitrary objects, or "documents". What it you want to provide semi-flexible capabilities when part of your table schema is defined by developer and fixed, but user still can extend it with... well, pretty much anything?

Flexilite can help you as a developer to deal with both major cases mentioned above:
- make database schema evolution process for developer as easy as possible
- allow end-users make their own changes in database schema.
 


## Why SQLite?
SQLite is widely used - from smartphones, to moderately used websites, from embedded devices, to rich desktop applications. It is reliable, fast and fun to use. And most importantly, SQLite has all features needed for achieving of Flexilite goals. 

## Are other databases supported?
Current;y it is SQLite only. We also have plans and ideas about implementing Flexilite on PostgreSQL.
