# To-Do list

###Mem leaks
Close statements, free allocated memory
*Done*

###MATCH function 
MATCH for plain unindexed text. Borrow from SQLite sources (FTS3 or FTS5)
*Done (more optimization required - using SQLite FTS3 parser and regex)*

###Range properties
Generate 2 scalar columns (with link from high bound prop to low bound prop)
*Done* TODO Test

###flexi_import_data

```
(
    {
        sourceDatabase?:string,
        sourceTable:string,
        targetClass?:string,
        propertyDefs?: any,
        propertyMap?: {[columnName:string]:string},
        whereClause?:string
        }
)
```


###flexi_prop_create
Scalar and reference/nested object

###flexi_prop_merge
Range props and text props

###Index support
Set ctlo and ctlv flags, tests
Ensure that indexes are used (via EXPLAIN)

###Use full text index
insert/update/delete into [.full_text_data]

###Use rtree for range search
insert/update/delete into [.range_data]

###Convert database
northwind, chinook, ttc routes
Try SQL queries, compare size and speed

###Test SQL 
Use existing SQLite tests (Sqllogictest) [[http://www.sqlite.org/sqllogictest/doc/trunk/about.wiki]]

###Fixed columns
Support for fixed columns (A-P) for scalar values. Includes unique and non-unique indexes,
full text indexes, rtree indexes
 
###Search statistics
Accumulate search statistics. Use external DB file with 1 table:
```
create table if not exists [.search_stat] 
(PropertyID integer,
EqCount int default 0,
CmpCount int default 0,
MatchCount int default 0,
LastUpdated datetime (julian)
NotNullCount 
);
```

####flexi_class_alter
Function to create new or modify existing class with basic refactoring support

```
flexi_class_alter(className:text, newClassDefinition:JSON1 [, newClassName:text])
```
Properties are identified by names. Property renaming is not supported in this API.
For property renaming use flexi_prop_alter.
Transformations supported by this function:
- add new property(ies)
- drop property(ies)
- change property attributes (type, validation, UI)

####flexi_class_drop

####flexi_class_create
*Done*

####flexi_props_to_object

####flexi_object_to_props

####flexi_struct_merge

####flexi_struct_split

####flexi_object_move
Moves object(s) to a different class (with property mapping)

####flexi_remove_dups
Removes duplicated objects with auto correction of links
 
####flexi_prop_split
 


####flexi_prop_alter

```
flexi_prop_alter(className:text, propName:text, propDef:JSON1[,newPropName:string])
```

####flexi_prop_drop

####flexi_ref_create

####flexi_ref_drop

####flexi_object_load
flexi_object_load(objectID)
Returns given object will all linked and nested objects, in JSON format

####flexi_class_optimize
Based on search stats, determines optimal storage and indexing for the given class.

####flexi_object_save

###Duktape

Integrate Duktape JavaScript engine into library.
Support for custom functions with interface compatible with sqlite3 node.js
Support for triggers and validation rules in JavaScript
Custom converters/formatter in JS

##Article(s) for CodeProject

