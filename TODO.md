* test flexi_ClassDef_create
* flexish - node.js utility (TypeScript)
* generate schema from non-Flexi database
* support for indexes when saving data
* use indexes when loading data
* Support MATCH for non-indexed data
* flexi_class_alter
* flexi_prop_* (create, alter, delete)
* flexi_relation_create
* flexi_query - to retrieve data

* create/destroy DBContext
* Port class load to ClassDef
* &#10004; Use RapidJSON / NLohmann
* Update data - implement

* &#10004; add ts-loader
* &#10004; Setup webpack for transpiling and bundling JS code
* &#10004; Add lodash
* &#10004; upgrade sqlite to 3.20.1
* &#10004; Define better-sqlite3.d.ts for API (@types already defined)
* &#10004; Find out how to pass and get arrays of values to/from Duktape (vectors are supported)
* &#10004; Create Database, Statement, SqliteError .cpp classes and their 
counterparts in TS to have subset of better-sqlite3 API
* &#10004; Register sqlite classes in DukContext

* Verify destructors work (add all objects to set in DukContext?)
* &#10004; Check std::map and std::unordered_map (_not relevant after switching to Duktape_)
* Check how throw is handled by Duk - enable #define for c++ exceptions
* &#10004; JS script to extend classes with methods not supported by Dukglue (_not relevant_)
export function CreateDBContext(db: Database, dbHandle: number)
* Create DBContext.ts class to keep connection specific
data: Database, statements, user info, class definitions, cache of referenced values etc.

* merge classes
* load class def
* save class def
* validate property
* ? port AccessRules to Lua
* try tests using busted
* flexi_DataUpdate
* &#10003; configure luacheck
* &#10003; how document Lua code
* extend flexiActions - function to table, with help and description
* toJSON, flexi schema
* try to bundle .lua files into DLL using luajit -b 
* Flexish. Schema generate:
    - Name, Description special properties - use any text field, if it is the only text or only indexed text field
    e.g. Regions should have name and description = RegionDescription
    - &#10003; maxLength == 15 for all text properties
    - &#10003; Employees does not have specialProperties -> {name=LastName}
    - &#10003; Product.Categories? should be Product.Category
    - &#10003; Products.Categories - maxOccurrences should be 1, not maxint. 
    - &#10003; Products: prop Category (singular), not Categories (plural)
    - &#10003; Define reverse properties for FKEY (not needed)
    - main.c - compile Flexish into standalone exe. (use CMakeLists.txt to list files and compile lua to .o files)
    - handle non existing database - report error
    
* SQL schema:
    - &#10003; split .nam_props to .sym_names and .class_props
    - &#10003; add vtypes column to .objects (A-P types)
        3 bit per column, 0 - 7, to keep actual type: date/time, timespan (for float), symname, money (for integer), enum (for text and
        integer), json (for text)
    - &#10003; allocate ColumnMap
    - &#10003; save .classes to get ID, then save properties with new ClassID, then update .classes with JSON
    - &#10003; columns A - P
    - define schemas for name, property, class. Use it for validation of class/property def
    - generate dynamic schema for object, to validate input data 
    - enumDef - process and save. Check if reference is resolved
    
* Class create:
    - create range_data_XXX table if needed
    
   
* Insert data:
    - parse JSON to Lua table
    - For every object in payload -
        - validate properties, find property IDs by name
        - call custom _before_ trigger (defined in Lua), first for mixin classes (if applicable), then for *this* class
        - validate data, using dynamically defined schema. If any missing references found, remember them in Lua table
        - save data, with multi-key, FTS and RTREE update, if applicable
        - call custom _after_ trigger (defined in Lua), first for mixin classes (if applicable), then for *this* class
    - Process unresolved references. If there are still unresolved refs, rollback entire update and raise error 
    (with complete report available on separate call)
    
* Query:
    - parse JSON to Lua table
    - traverse tree and generate SQL
    
* General:
    - &#10003; move flags (CTLV* ) and related logic to separate module
    - Review README.md. Cleanup and move text to /doc


         

