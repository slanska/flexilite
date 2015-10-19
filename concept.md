## Views as tables

SQLite has few really nice features which allow to implement relational databasce schema in a very non 
traditional way. 
These features are:
* type affinity - any cell can have any value
* partial indexes
* updatable views
* triggers
* WITHOUT ROWID (clustered) indexes

Based on these features, it is possible to implement the following design.
There is one table, which structure is defined the following way:
 
 'create table Objects (ObjectID integer, ClassID integer, A, B, C, D, E, F, G, H, I, J, K, L, M,
 N, O, P);
 
For the sake of simplicity we assume that typical relational table has no more than 16 columns (and from my own experience 
80-90% of all tables follow this assumption). Then, definition of, let's say, table Orders
would look as follows:
 
 'create view Orders as select ObjectID as OrderID, A as OrderDate, B as CustomerID, C as Status' etc.
 
(You can think about this approach as columns in Excel - A for OrderDate, B for CustomerID and so on).
 
With SQLite updatable views we can add INSTEAD OF triggers, to map virtual table (view Orders) to the real table (Objects).
  
Insert trigger:
  
Update trigger:

Delete trigger:


Thus, 'insert into Orders (OrderDate, CustomerID, Status) values ('2015-10-12', 123, 'Pending')' works just like INSERT 
on normal table. 

Why is it needed and what are benefits of this design comparing to the traditional approach?
Main advantage are related to more performant data schema refactoring:
* dropping column is more efficient - there is no need to create temporary table, copy data across, then drop old table and rename
temporary table. All needed is to a) recreate view definition and b) set to null corresponding column for the given class ID.
 And even (b) is not mandatory - excluding column from view would suffice.
* adding new column with default value is more efficient. View definition can include expression like:
'create view Orders as select coalesce([C], 'Pending') as Status', so all null values will automatically return required default value.
* similarly, altering column and specifiying new default value will not require massive table updates. Dropping and re-creating view
would be sufficient.
* moving records from one table to another. Let's say, we have several tables for different order types (ShippingOrders, ManufacturingOrders etc.)
In case if user realizes that he placed few records into wrong table, he would need to run script looking like this:

'insert into ShippingOrders select from ManufacturingOrders where;
delete from ManufacturingOrders where'

which will underneath turn into the following construct:

insert or replace into Objects (ClassID) values (1)
delete from Objects where ClassID = 2 and where'

Since OrderID is supplied, existing records in Objects will be updated (for insert statement) and ignored (for delete
statement, as after applying INSERT OR REPLACE there would be no record with ObjectID = 1 and ClassID = 2)


## How about indexes, dude?

So far, our views could serve as virtual tables for all basic CRUD operations. But for bigger amounts of data we need indexes.
This requirement can be accomplished by utilizing another excellent features of SQLite - partial indexes.
Presented model is good enough for small amount of data, few thousands of rows. For bigger number of records indexing is needed to
gain fetch performance comparable to traditional relational database. This is where SQLite partial 
indexes come to rescue.
Objects table has ctlo column, Values table has ctlv column. Both serve purpose of controlling 
different aspects of individual record, including indexing.
For Objects, ctlo column is a bit mask, which 


## Entity Attribute Values and Class Relations (EAV/CR)

All this makes sense, but how about cases when number of columns exceeds 16? This will be resolved by utilizing Entity-
 Attribute-Value (EAV) model, where there is a separate record for every attribute of the object.
 Comprehensive documentation on EAV model can be found here:
 
## Scalars and arrays
Values table has the following structure:
ObjectID
PropertyID
PropertyIndex
Value
ctlv
ClassID

there is unique clustered index by ObjectID, PropertyID, PropertyIndex

For attributes (scalar values) PropertyIndex = 0. For arrays or lists it will be 1 or more. The same for references.
Thus it is possible to store multiple values for the same property.
 
## References

## More about indexes. Full text search

## Tracking changes

Table ChangeLog is used for storing full history of all changes. 

## Data refactoring patterns

- Add new class
- Add new property
- Remove property
- Rename property
- Change property type, require, check constraints
- Convert scalar property to array of values
- Extract one or more properties from one class to another class
- Merge

## XML, JSON or YAML



