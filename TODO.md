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
    - &#10003; define schemas for name, property, class. Use it for validation of class/property def
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
        - &#10003; save data, with multi-key, FTS and RTREE update, if applicable
        - call custom _after_ trigger (defined in Lua), first for mixin classes (if applicable), then for *this* class
    - Process unresolved references. If there are still unresolved refs, rollback entire update and raise error 
    (with complete report available on separate call)
    
* Query:
    - parse JSON to Lua table
    - traverse tree and generate SQL
    
* General:
    - &#10003; move flags (CTLV* ) and related logic to separate module
    - Review README.md. Cleanup and move text to /doc
    - &#10003; bit 52 operations - implementation and tests. Use Python to get verified data
    - &#10003; set ctlv, vtypes, ctlo on class & class prop save
    - deferred saving of references
    - try sandbox mode (for custom functions, triggers, filter expressions etc.)
    - generate user formatted JSON for db/class/property definition
    - flexi_CreateClass -> check name and class existence, create empty record, then - flexi_AlterClass
    - flexi_AlterClass - merge user definitions, validate with schema, proceed
    - &#10003; complete schema definition for class and property
    - &#10003; complete object schema generation
    - schema for query
    - rename flexi_AlterClass to flexi_CreateAlterDropClass. Move flexi_CreateClass and flexi_DropClass to this module
    - refactor ClassDef and PropertyDef. D for all data loaded from db (matching table columns). D.Data for parsed JSON
    so PropertyDef.D.Data.rules.type == 'text' (for example). ClassDef.D.Data will not have properties once loaded from DB, it 
    will be ClassDef.Properties (by name) and DBContext.ClassProps (by ID). PropertyDef.D.Data will have data for class def JSON
    - DBContext on init, create/open aside database for log and statistics
    - check how SQLite query analysis engine can be used for virtual tables
    - TEMP TRIGGER on .ref-values to check minOccurrences..maxOccurrences
    - date validation
    - PropertyDef - convert defaultData to property specific format (e.g. string date to number)
    - base64 for blob processing. Set path (copy lbase64 to LuaJIT path)
    - multi-key indexes: save data
    
    
- &#10003; Saved JSON in .classes do not have property rules    
- Saved JSON in .classes do not have special properties & indexing    
    
- &#10003; ensure that create classes is ok
- &#10003; try insert data
- enum property - generate enum class, save items
- &#10003; try sandbox mode

- ignore case for schema - property types
- &#10003; ignore case for class and property names - custom Dictionary class?
- &#10003; generate valid SQL for indexed properties
- &#10003; filter records using Lua sandbox
    - &#10003; Params
    - &#10003; Literal values
- &#10003; Boxed() for DBValue
- unit tests for insert and query
    - Datetime
- update and delete objects
- Enum processing
- References processing
- unit tests for all property types, number of occurrences
- property rules - object or array of objects (union)


text|integer -> enum -> reference
enum -> mixin
properties -> mixin -> reference
enum -> reference

**2018-04-29**

- DBObject.GetData - return valid JSON-like table
- Enum/FKey processing:
    - Validation
    - Creating/finding enum class
    - Update deferred references
    - Use in search (including indexed)
- Update/delete objects
- Referenced properties access
- Save object - ctlv & ctlo, multi-key index

**2018-05-26**

- &#10003; Load Chinook and Northwind to memory
- DBProperty: allow nil/0/negative indexes for appending values
- Change xpcall - use context 
- Export to JSON
- tests to check data after load

**2018-06-09**

- deferred actions in DBContext
- enum property - as pseudo-computed property for reference property
- multi key primary index support
- full text and range index - complete
- &#10003; upgrade SQLite to 3.24.0 (2018-06-04) 

**2018-07-07**

- &#10003; flexi_func.cpp: struct for context
- &#10003; use sqlite memory alloc
- build on Windows
- build on Linux
- &#10003; lua2lib - non .lua files treat as string resources
 (wrap into return encoded string)
- flexi test: run 'flexi' tests
