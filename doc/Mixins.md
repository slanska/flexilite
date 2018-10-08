####Mixins

Any reference properties, including nested and enums, with _rules.maxOccurrences_ = 1, 
can have an optional boolean attribute - **mixin**. When true, all properties and custom methods
of referenced class are semantically considered as belonging to the host object.

This technique allows to compose new classes from one or many source classes, making possible:

- emulation of single inheritance
- emulation of multiple inheritance

**flexish_cli** utility recognizes cases with possible mixin references when 
generating Flexilite schema from existing SQLite database.
General rule is:
- there is a primary key on a single column
- there is a foreign key relation from the primary key column to another table. 

For example, **Nortwind** sample database has tables **Orders** and **InternationalOrders**.
Both tables have **OrderID** column, and in **InternationalOrders** it is also a foreign key to 
**Orders**.  
This is considered by flexish_cli as sufficient ground to treat InternationalOrders as a sort of
a superclass of Orders.

We will use these tables to demonstrate how mixins are organized in Flexilite.

In Flexilite, **InternationalOrders** is declared as class which has, among other, scalar properties,
a mixin property called Order, with reference to **Orders** class.
Complete list of properties of **InternationalOrders** is as follows:

- OrderID - enum property, and also a user-defined ID
- CustomsDescription - text
- ExciseTax - money
- OrderID_ref - auto generated internal reference property, paired with OrderID and 
pointing to Orders. It has **mixin=true** and this makes all properties of referenced object 
in **Orders** class (like CustomerID, EmployeeID, OrderDate etc.) to be directly available 
as properties of **InternationalOrders**.

Few more notes on mixins:

- rules.maxOccurrences must be 1. Other values are not allowed.
- Properties of mixin class can be accessed directly (without property name qualifier) as well as using 
property qualifier. For example, in triggers, queries or functions OrderDate can be accessed as InternationalOrders.OrderDate or 
InternationalOrders.Order.OrderDate. These constructs are identical.
- referenced objects with mixin=true cannot reference themselves directly or indirectly, 
i.e. recursion is not allowed.
- mixin objects are stored and manipulated as standalone objects belonging to their own class.
This, in particular, means that they are indexed the same way as normal objects of the same class 
and participate in searches.

#####Host object
Object that has mixin references is called host object. It can be referenced as mixin by other objects,
thus ending in multi-level structure similar to class hierarchy. Top level object (the real host)
can be referenced from any mixin objects as **self**, with access to all properties and methods.

Any given object may belong to single host object. Attempt to host an object which is already hosted, in
another object, with raise an error. Multiple mixins are OK, as far as every single object is a mixin for
only one host object.





