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
    - Employees does not have specialProperties -> {name=LastName}
    - Product.Categories? should be Product.Category
    - Products.Categories - maxOccurrences should be 1, not maxint. 
    - Products: prop Category (singular), not Categories (plural)
    - Define reverse properties for FKEY
    - main.c - compile Flexish into standalone exe. (use CMakeLists.txt to list files and compile lua to .o files)
    - define schemas for name, property, class. Use it for validation of class/property def
    - generate dynamic schema for object, to validate input data 
    - handle non existing database - report error