* test flexi_ClassDef_create
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

* merge classes
* load class def
* save class def
* validate property
* ? port AccessRules to Lua
* &#10003; try tests using busted
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
    - &#10003; main.c - compile Flexish into standalone exe. (use CMakeLists.txt to list files and compile lua to .o files)
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
- &#10003; build on Windows
- &#10003; build on Linux
- &#10003; lua2lib - non .lua files treat as string resources
 (wrap into return encoded string)
- flexi_test: run 'flexi' tests
- &#10003; switch to OpenResty lua-cjson (fix for LuaJIT 2.1 compatibility)

**2018-07-14**

- [x] use GC64 for luajit 2.1
- [x] switch to openresty luajit for all platforms
- [x] clean up JS tests and convert them to lua
- [x] move util/* to tools
- [ ] move definitions.d.ts to metacix project
- [?] delete typings
- [x] merge flexish cmakefiles with main one
- [x] build flexish_cli (except Linux)
- put compiled binaries to git
- install.md

**2018-07-23**

- [x] Windows: flexish_cli - LuaFileSystem
- [x] Windows:debug sqlte_shell
- [x] Windows: try DB Tools and load flexilite
- [x] remove openresty/luajit

**2018-08-06**

- [x] conditional package.cpath for Windows version
- [x] **No need - use MSVC**. static linking of gcc libraries on Windows (libstdc++-6.dll and libgcc_s_dw2-1.dll)
- [x] install busted and mobdebug on &#10003; Linux and Windows VMs
- [x] create image of SD200 on Adata - better to copy contents directly
- [x] handle <require 'sql.dbschema'> in busted tests
- [x] No need. install MingW 64 bit on Windows VM. Build. Check cross platform build - 32 or 64 bits.
- update README.md: move most of text to ./doc
- Flexish_cli: load data
- [x] Flexish_cli: use ansicolors
- Flexish_cli: query
- Flexish_cli: configure database
-[x] ~~get rid of Lua date, use Penlight date instead~~ - Penlight Date does not provide feature to get 
number of days starting from 0 AD
- Flexish_cli: help - extended info
- Flexish_cli: schema - check enum, multi key index and many-2-many
- Flexish_cli: unit tests
- [x] cmake: copy lua51.dll to ./bin 
- [x] check if lib/luadec is used -> not needed.
- [x] try original make with LuaJIT 2.1 on Linux to get static lib for flexish_cli

Employees: EmployeeID
EmployeesTerritories: EmployeeID, TerritoryID
Territories: TerritoryID

**2018-10-20**

- [x] flexish_cli: create mixin properties
- [x] flexish_cli: process many2many tables (2 or 3 columns)
- [x] ~~flexish_cli: output 2 files - sql and json - N/A~~
- 'load' - from file
- 'create property' - handle missing JSON, or string instead of JSON (as type)
- sqlite3value_to_luavalue and luavalue_to_sqlite3value (from lsqlite?)
- [x] ~~flexi_rel_vtable: finish (lua ffi etc.)~~
- [x] ~~flexi_data_vtable: finish (ffi etc.)~~
- [?] import/export xml
- [?] add Slovak sample social network database

**2019-06-30**

-[x] move ffi declarations for virtual table to flexi vt
-[x] remove flexi_rel tests and C code
-[x] refactor deferred actions
-[x] 'Territories' appears twice in view EmployeeTerritories

**2019-08-11**

-[x] Import reference value
-[ ] Add event emitter library
-[ ] Export data
-[ ] import data: if no class found, try existing updatable view
-[ ] fix ctlv and property index 
-[ ] import data - check classes, if not found, check existing tables (including virtual)
-[ ] export data (the same format as import)
-[ ] test imported data for specific rows/values (busted tests)
-[ ] enum properties
-[ ] boxed object: access to referenced properties
-[ ] query: fix unit tests

**2019-08-24**

-[ ] Generate JSON from db - use { "$udid": 1 } for reference values
-[ ] Generate JSON from db - use $udid value for enum values
-[ ] Value for reference - integer. Set to 0 on import, to be fulfilled at the end 
-[ ] Value for enum - default value for corresponding $udid type (string or number). Set to 0 or '' on import, to be fulfilled at the end
-[ ] ImportDBValue- return function for reference/enum to be called at the end to resolve reference
-[ ] refactor methods of PropertyDef to getCapabilities:
    GetVType -> vtype
    CanBeUsedAsUID (-> canBeUsedAsUDID)
    ColumnMappingSupported (-> columnMappingSupported)
    supportsRangeIndexing 
    getNativeType -> nativeType
    GetSupportedIndexTypes -> supportedIndexTypes




