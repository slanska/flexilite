####Reference Properties

Unlike scalar properties, reference properties establish link between 2 objects, so value of reference property is another object.
There are few subtypes of reference properties:

- regular reference properties

- nested objects

- enumerations (or simply enums) 

All reference properties are internally stored and accessed the same way, thus allowing 
few interesting possibilities with schema refactoring.

Flexilite data model treats one-to-one and one-to-many relations 
as subsets of more general case - many-to-many. This allows to switch easily from one type
of relation to another. 

All types of reference properties can be used as [mixins](Mixins.md)
