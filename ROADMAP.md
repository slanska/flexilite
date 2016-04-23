## To-Do list

####Mem leaks
Close statements, free allocated memory

####MATCH function 
MATCH for plain unindexed text. Borrow from SQLite sources (FTS3 or FTS5)

####Range properties
Generate 2 scalar properties with link to each other

####Index support
Set ctlo and ctlv flags, tests

####Use full text index

####Use rtree for range search

####Test SQL 
Use existing SQLite tests (Sqllogictest) [[http://www.sqlite.org/sqllogictest/doc/trunk/about.wiki]]
 
####Search statistics

####flexi_class_alter
Function to create new or modify existing class with basic refactoring support

####flexi_class_drop

####flexi_class_create

####flexi_props_to_object

####flexi_object_to_props

####flexi_struct_merge

####flexi_struct_split

####flexi_object_move
Moves object(s) to a different class (with property mapping)

####flexi_remove_dups
Removes duplicated objects with auto correction of links
 
####flexi_prop_split
 
####flexi_prop_merge

####flexi_prop_create

####flexi_prop_alter

####flexi_prop_drop

####flexi_ref_create

####flexi_ref_drop

####flexi_object_load
flexi_object_load(objectID)
Returns given object will all linked and nested objects, in JSON format

####flexi_class_optimize
Based on search stats, determines optimal storage and indexing for the given class.

####flexi_object_save