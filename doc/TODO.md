* &#10004; define TypeScript interfaces for basic operations
* test flexi_ClassDef_create
* &#10004; add Northwind to Git
* flexish - node.js utility (TypeScript)
* &#10004; JsonHelper
* &#10004; initialize Duktape context
* generate schema from non-Flexi database
* convert Northwind database to Flexi
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
* Find out how to pass and get arrays of values to/from Duktape 
* Create Database, Statement, SqliteError .cpp classes and their 
counterparts in TS to have subset of better-sqlite3 API
* Register sqlite classes in DukContext
* Verify destructors work (add all objects to set in DukContext?)
* Create DBContext.ts class to keep connection specific
data
* Load JS bundle in DukContext (embed into lib?)
* Check duktape debugger (VS Code)
* Flexi 'create class' - in TS
* ??? flexish - convert to c++ exe with duktape
* Flexi_data 'update' - in c++/ts
