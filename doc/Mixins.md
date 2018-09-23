Mixins are special property type which allow to compose new classes from one or many source classes.
Concept of mixins allows few interesting use cases, such as:

- emulation of single inheritance
- emulation of multiple inheritance

For example, **Nortwind** sample database has tables **Orders** and **InternationalOrders**, 
where **InternationalOrders**, in fact, is the extension of Orders (kind of subclass, in terms of object oriented programming).
We will use these tables to demonstrate how mixins are organized in Flexilite.

In Flexilite, **InternationalOrders** is declared as class which has, among other, scalar properties,
a mixin property called Order, with reference to **Orders** class.
Complete list of properties of **InternationalOrders** is as follows:

- OrderID - integer, user-defined ID
- Order - mixin, references Orders class
- CustomsDescription - text
- ExciseTax - money

Semantically, objects of **InternationalOrders** automatically get all properties of **Orders**, like
CustomerID, EmployeeID, OrderDate etc.

Mixins can be explained in terms of nested objects, and in fact, they are subset of nested objects with
few distinctive features.

These features are:

- maxOccurrences must be 1. Other values are not allowed.
- Properties of mixin class can be accessed directly (without property name qualifier) as well as using 
property qualifier. For example, in triggers, queries or functions OrderDate can be accessed as InternationalOrders.OrderDate or 
InternationalOrders.Order.OrderDate. These constructs are identical.
- similarly to nested objects, mixins cannot reference themselves, i.e. recursion is not allowed.

Mixin objects are stored and manipulated as standalone objects belonging to their own class.
This, in particular, means that they are indexed the same way as normal objects of the same class 
and participate in searches.

