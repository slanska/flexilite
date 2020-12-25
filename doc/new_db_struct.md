#### Proposal of new DB structure and concept

- Database schema replicates hierarchical structure (XML would be the best example)
- Main table, \[.nodes\], has columns: key, value, ctlv, ext_data
- key is (short) blob, which normally has length ~7-9 bytes, concatenated from compacted integer values
- key structure consists of pairs: A-N-A-N..., where A are integer IDs of attribute names, N are
sequential numbers of elements within the same tree level (based on 1).

Example:
```xml
<widget id="com.appted.appted" version="0.0.1" xmlns="http://www.w3.org/ns/widgets" xmlns:cdv="http://cordova.apache.org/ns/1.0">
    <content src="index.html" />
    <access origin="*" />
    <allow-intent href="*" />
    <allow-navigation href="*" />
    <preference name="SplashScreenDelay" value="50000" />
    <preference name="auto-hide-splash-screen" value="false" />
    <platform name="android">
        <preference name="SplashMaintainAspectRatio" value="true" />
        <preference name="FadeSplashScreenDuration" value="300" />
        <preference name="SplashShowOnlyFirstTime" value="false" />
    </platform>
</widget>
```

Assuming that **widget** has ID = 1, **content**'s ID = 2, **access**' ID = 3, **allow-intent**'s ID = 4
and so on, keys will look like compacted sequences of integers

```xml
<widget >\1\1
    <content src="index.html" />\1\1\2\1
    <access origin="*" />\1\1\3\1
    <allow-intent href="*" />\1\1\4\1
    <allow-navigation href="*" />\1\1\5\1
    <preference name="SplashScreenDelay" value="50000" />\1\1\6\1
    <preference name="auto-hide-splash-screen" value="false" />\1\1\6\2
    <platform name="android">\1\1\7\1
        <preference name="SplashMaintainAspectRatio" value="true" />\1\1\7\1\8\1
        <preference name="FadeSplashScreenDuration" value="300" />\1\1\7\1\8\2
        <preference name="SplashShowOnlyFirstTime" value="false" />\1\1\7\1\8\3
    </platform>
</widget>
```

Compact storage for integers means that values -64..+63 will use 1 byte, -8192..+8191 - 2 bytes,
-1,048,576..+1,048,575 - 3 bytes, -268,435,456..+268,435,455 - 4 bytes and so on.

- Entire database conceptually can be considered as one huge XML document, with *root* element and
arbitrary number of nested elements.

- Nested elements have longer keys (typically, requiring 3 bytes per each level - 2 bytes to encode attribute name ID
and 1 byte for position)

- Such key structure allows (a) storing adjacent data close to each other, in physical sense, b) retrieve 
data for any node of the tree in a single request, by key range

- With this schema architecture, any XML/JSON/YAML document can be appended into any position of the database tree

- Flexilite supports internal references, i.e. when value contains another key within the same database. 
This features allows to implement various referencing models, similar ro what traditional relational databases
(RDBMS) allow, but not only that - it allow many other interesting scenarios.

- Flexilite also supports external references - to other databases. This to be covered in a separate topic.

- Traditional RDBMS structure - database/table/row/column - can be presented in terms of Flexilite storage
as follows:

```xml
<root>
    <table1><!--row 1 of table1-->
        <column1>Some Value</column1>
        <column2>Some Value</column2>
        <column3>Some Value</column3>
    </table1>
    <table1><!--row 2 of table1-->
        <column1>Some Value</column1>
        <column2>Some Value</column2>
        <column3>Some Value</column3>
    </table1>
    <table2><!--row 2 of table2 -->
        <column1>Some Value</column1>
        <column2>Some Value</column2>
        <column3>Some Value</column3>
    </table1>    
</root>
```   

- Keys for such structure can be presented as \table-name-is\row-no\column-name-id\1, 
e.g. \1\1\10\1, \1\1\11\1 and so, on. Normally, key for any individual value will be 6-8 bytes.

- Table \[.nodes\] has the only primary index by key.

- Node key can be split into 2 parts: attr path (containing only node name IDs) and index path 
(containing only node indexes)

- Table \[.schema\] defines classes and properties, i.e. abstract typed data structures. 

- Properties can be of atomic (simple) types, such as string, integer, date, or references to other classes

- Properties have minOccurrences and maxOccurrences attributes which define how many nodes may and need to
be specified

- Reference properties can be for a specific type, or for the list of multiple allowed types. This feature
allows polymorphism. 

- By default, data is not typed, i.e. anything can be stored anywhere. Type constraint is forced by
mapping node key of data tree to a specific class. Mapping can be done on entire node key, or (more practical)
on attribute path part only, so that all nodes, matching specific names path, will be forced to comply
with the given class definition.

- Type mapping can be applied on entire key (exact mapping), or on wild card, where any element of key can be set to 0.

- 


  
