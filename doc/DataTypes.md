Flexilite supports the following data types:

* Text
* Integer
* Number
* Boolean
* Date (stored as double, Julian value)
* Time/timespan (fraction part, stored as double, Julian value)
* DateTime (Date + Time)
* Blob
* Symbol
* Enum
* Reference (simple, nested and mixin)

### Text

Basic value type, compatible with all other data types. Stored as UTF-8 string.
Maximum length is 1 GB. Can be indexed in BTree index and/or in full text index
There is number of subtypes for basic text type, including email, url, phone etc. 
(basically, the same subtypes that HTML5 supports)
These subtypes are used not only for validation purposes, but for special actions,
for example - 'find all email values in the system'

### Integer

Stored as SQLite integer value. Can be indexed or indexed for range search
(using RTree index)

### Number
Stored as SQLite float value (8 byte). Can be indexed with BTRee or included into range search
(using RTree index)

### Symbol

This is a special type which is exposed as text value. Internally it is stored
as a reference to record in **[.names]** table. Supports translation based on currently
selected language. When searching by text values, [.names] table always participates
in search. When property value gets saved and its type is text, this value gets
stored in **[.names]** table and ID is stored instead. Can be indexed for fast search
by joining with **[.names]** table. Values in **[.names]** table are always indexed and
included into full text index. Symbol type is used standalone, as an efficient way
to store translatable and non unique text values, or as a part of enum definition.
Symbols in **[.names]** table have the following attributes:
* culture (optional)
* value
* ID
* Code (i.e. custom ID, optional)

### Enum

Enum is defined as collection of symbol values. Property of type of enum may have only ID of one of the
symbols in the enum collections. Collection can be extended by adding new items or shrunk. When shrunk, existing values
will stay as is and will be treated as a standalone symbols, not belonging to the enum definition.
Enums are used in cases when property may have only certain values in the predefined list.
Enums are often get refactored to references, when symbol value get converted to new objects.
Though internally enum properties are stored as symbol IDs, they can be exposed via enum code.
Every Enum is defined as special, simplified class, with few pre-determined properties. One of them is always Value, type of symbol.

### Reference

