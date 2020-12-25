---
--- Created by slanska.
--- DateTime: 2017-11-18 12:06 PM
---

local class = require 'pl.class'
local tablex = require 'pl.tablex'
local ansicolors = require 'ansicolors'
local Constants = require 'Constants'

---@class ISQLiteTableInfo @comment row returned by [select * from sqlite_master;]
---@field type string
---@field name string
---@field tbl_name string
---@field rootpage number
---@field sql string

---Info on SQLite column indexing
---@class IColIndexXInfo
---@field indexName string @description empty for primary key
---@field desc boolean
---@field seqno number
---@field key_count number

---@class ISQLiteColumnInfo @comment Structure returned by [pragma index_list(TABLE_NAME);] plus column list
---@field cid number
---@field name string
---@field type string @comment integer | nvarchar(NNN)...
---@field notnull number @comment 0 | 1
---@field dflt_value any
---@field pk number @comment 0 | 1
---@field indexing IColIndexXInfo[]

---@class ISQLiteIndexColumnInfo @comment row returned by [pragma index_info(INDEX_NAME);]
---@field seqno number @comment Starts from 0
---@field cid number @comment column ID
---@field name string @comment column name

---@class ISQLiteIndexInfo
---@field seq number
---@field name string
---@field unique number @comment 0 | 1
---@field origin string
---@field partial number
---@field cols ISQLiteIndexColumnInfo[]

---@class ISQLiteForeignKeyInfo
---@field id number @comment 0-based FKEY item ID
---@field seq number @comment 0-based, position in multi-column FK
---@field table string @comment to-table name
---@field from string @comment from-column name
---@field to string @comment to-column name
---@field on_update string @comment NO_ACTION, CASCADE, NONE, SET_NULL...
---@field on_delete string @comment NO_ACTION, CASCADE, NONE, SET_NULL...
---@field match string @comment NONE...

---@class ITableInfo
---@field table string
---@field columnCount number
---@field columns table<number, ISQLiteColumnInfo> @description map by SQLite column index
---@field columnsByName table<string, ISQLiteColumnInfo> @description the same objects as in columns by accessed by column name
---@field inFKeys ISQLiteForeignKeyInfo[]
---@field outFKeys ISQLiteForeignKeyInfo[]
---@field manyToManyTable boolean
---@field multiPKey boolean
---@field pkey ISQLiteIndexInfo
---@field indexes ISQLiteIndexInfo[]

---@class IFlexishResultItem
---@field type string
---@field message string
---@field tableName string

---@param tbl any[]
---@param func function
---@return any[]
table.filter = function(tbl, func)
    local result = {}
    for k, v in pairs(tbl) do
        if func(v) then
            result[k] = v
        end
    end

    return result
end

---@class SQLiteSchemaParser
---@field outSchema table<string, ClassDefData> @comment list of Flexi classes to be exported to JSON
---@field tableInfo ITableInfo[] @comment list of internally used table information
---@field results IFlexishResultItem[]
---@field referencedTableNames string[]
-- -@field SQLScript table @comment pl.List
---@field SQLScriptPath string @comment Absolute path where SQL script will be saved

local SQLiteSchemaParser = class()

---@param db userdata @comment sqlite3.Database
function SQLiteSchemaParser:_init(db)
    ---@type ITableInfo[]
    self.tableInfo = {}

    -- ClassDefCollection
    self.outSchema = {}

    --FlexishResults
    self.results = {}

    self.db = db

    -- List of table names that are references by other tables
    -- Needed to enforce id and name special properties
    self.referencedTableNames = {}

    --self.SQLScript = List()
end

-- Mapping between SQLite column types and Flexilite property types
local sqliteTypesToFlexiTypes = {
    ['text'] = { type = 'text' },
    ['nvarchar'] = { type = 'text' },
    ['varchar'] = { type = 'text' },
    ['nchar'] = { type = 'text' },
    ['memo'] = { type = 'text' },

    ['money'] = { type = 'money' },

    ['numeric'] = { type = 'number' },
    ['real'] = { type = 'number' },
    ['float'] = { type = 'number' },

    ['bool'] = { type = 'boolean' },
    ['bit'] = { type = 'boolean' },

    ['json1'] = { type = 'json' },

    ['date'] = { type = 'date' },
    ['datetime'] = { type = 'date' },

    ['time'] = { type = 'timespan' },

    ['blob'] = { type = 'binary', subType = 'image' },
    ['binary'] = { type = 'binary', subType = 'image' },
    ['varbinary'] = { type = 'binary', subType = 'image' },
    ['image'] = { type = 'binary', subType = 'image' },

    ['ntext'] = { type = 'binary', maxLength = -1 },

    ['integer'] = { type = 'integer' },
    ['smallint'] = { type = 'integer', minValue = -32768, maxValue = 32767 },
    ['tinyint'] = { type = 'integer', minValue = 0, maxValue = 255 },
}

---@param sqliteCol ISQLiteColumnInfo
---@return PropertyDef
function SQLiteSchemaParser:sqliteColToFlexiProp(sqliteCol)
    local p = { rules = { type = 'any' } }

    if sqliteCol.type ~= nil then
        -- Parse column type to extract length and type
        local _, _, tt, ll = string.find(sqliteCol.type, '^%s*(%a+)%s*%(%s*(%d+)%s*%)%s*$')
        if tt and ll then
            tt = string.lower(tt)
            local rr = tablex.deepcopy(sqliteTypesToFlexiTypes[tt])
            if rr then
                p.rules = rr
                p.rules.maxLength = tonumber(ll)
            end
        else
            local rr = tablex.deepcopy(sqliteTypesToFlexiTypes[string.lower(sqliteCol.type)])
            if rr then
                p.rules = rr
            end
        end
    end

    return p
end

---Generates unique property name for the given class, based on given start prefix
---@param cls ClassDefData
---@param startPrefix string
---@return string
function SQLiteSchemaParser:getUniquePropertyName(cls, startPrefix)
    local result = startPrefix or ''
    local attempt = 1
    while true do
        if cls.properties[result] == nil then
            return result
        end
        attempt = attempt + 1
        result = (startPrefix or '') .. tostring(attempt)
    end
end

--[[
Iterates over list of tables and tries to find candidates for many-to-many relation tables.
Canonical conditions:
1) table must have only 2 columns (A & B)
2) table must have primary index on both columns
3) Both columns must be foreign keys to some tables
4) there is an index on column B (this is optional, not required)

If conditions 1-3 (or even 1-4) are met, this table is considered as a many-to-many list.
Foreign key info in SQLite comes from detail/linked table, so it is either N:1 or 1:1

For the sake of example let's take a look schema from Northwind database:
Employees -> EmployeesTerritories <- Territories

Once many-to-many table is detected, related tables get a new property each.
Employees get a new property "Employees.EmployeesTerritories" (as name of referenced table)
Territories get a new property "Employees".

Based on structure of original table, 'Employees.EmployeesTerritories' will be a master property
(mapped to PropertyID), 'Territories.Employees' - linked property (mapped to Value)

As far as 'EmployeesTerritories' exists (and not renamed), external data can be loaded to the
'EmployeesTerritories' virtual table. Note that actual class 'EmployeesTerritories' will not be created,
so if such a class to be created later, it will prevent importing data from external source.
]]

---@return number @comment Number of found many2many tables
function SQLiteSchemaParser:processMany2ManyRelations()
    --[[
    // Find tables with 2 columns
    // Check if conditions 2 and 3 are met
    // If so, create 2 relational properties
    /*
    Their names would be based on the following rules:
    Assume that there are tables A and B, with ID columns a and b.
    As and Bs are pluralized form of table names
    Properties will be named: As, or As_a (if As already used) and Bs or Bs_b, respectively
    ]]
    local result = 0

    for _, tblInfo in ipairs(self.tableInfo) do
        -- 1) table must have only 2 or 3 columns (A & B)
        if tblInfo.columnCount == 2 or tblInfo.columnCount == 3 then
            ---@type table<number, ISQLiteColumnInfo>
            local cols = tablex.deepcopy(tblInfo.columns)

            -- Check if primary key column is autoincrement integer
            if tblInfo.columnCount == 3 then
                -- primary autoincrement integer key - a) pk = 1 (and this is the only column with pk = 1),
                -- b) nullable, c) integer
                local pk_n = tablex.find_if(tblInfo.indexes,
                ---@param idx ISQLiteIndexInfo
                        function(idx)
                            return idx.pk == 1 and idx.type == 'integer' and idx.notnull == 0
                        end)
                if pk_n ~= nil and pk_n >= 1 then
                    table.remove(cols, pk_n)
                end
            end

            -- 2 remaining columns must be: a) foreign keys, b) form unique or primary index
            local fk_count = 0
            for _, col in ipairs(cols) do
                for _, fk in ipairs(tblInfo.outFKeys) do
                    if fk.from == col.name and fk.table ~= tblInfo.table then
                        fk_count = fk_count + 1
                        col.to_table = fk.table
                    end
                end
            end

            if fk_count == 2 then

                -->>
                --require('debugger')()

                -- Both columns (except ID) are foreign keys: this is many-to-many table

                -- Create enum property
                ---@type ClassDefData
                local cls1 = self.outSchema[cols[1].to_table]
                assert(cls1, string.format('Class %s not found', cols[1].to_table))

                ---@type ClassDefData
                local cls2 = self.outSchema[cols[2].to_table]
                assert(cls1, string.format('Class %s not found', cols[2].to_table))

                local refPropName = self:getUniquePropertyName(cls1, cols[2].to_table)
                local revRefPropName = self:getUniquePropertyName(cls2, cols[1].to_table)

                -- Create new ref property
                local propDef = {
                    rules = {
                        type = 'ref',
                        minOccurrences = 0,
                        maxOccurrences = Constants.MAX_INTEGER,
                    },
                    refDef = {
                        classRef = cols[2].to_table,
                        reverseProperty = revRefPropName,
                        viewName = tblInfo.table,
                        viewColName = cols[1].name,
                        reversedPropViewColName = cols[2].name,
                    }
                }

                cls1.properties[refPropName] = propDef

                -- TODO remove
                --[[ Append SQL script to create a new virtual table, using
                --original table name.
                --]]
                --local vt_sql = string.format([[create virtual table if not exists [%s]
                --using flexi_rel ([%s], [%s], [%s] hidden, [%s] hidden);
                --
                --]],
                --        tblInfo.table, cols[1].name, cols[2].name, cols[1].to_table, refPropName)
                --
                --self.SQLScript:append(vt_sql)

                -- Remove this table from list of classes
                self.outSchema[tblInfo.table] = nil

                print(ansicolors(string.format('%%{yellow}Table %s was detected as many-to-many relation storage and will be ported as updatable view%%{reset}', tblInfo.table)))
            end
        end
    end

    return result
end

---@param tableName string
---@return ITableInfo
function SQLiteSchemaParser:findTableInfoByName(tableName)
    for i, ti in ipairs(self.tableInfo) do
        if ti.table == tableName then
            return ti
        end
    end

    return nil
end

---@param indexName string
---@return string
function SQLiteSchemaParser:getIndexColumnName(indexName)
    -- TODO
    return ''
end

---Loads SQLite table columns and initializes tblInfo.columns
---@param tblInfo ITableInfo
---@param tblDef ISQLiteTableInfo
function SQLiteSchemaParser:loadTableColumns(tblInfo, tblDef)
    local tbl_info_st = self.db:prepare(string.format("pragma table_info ('%s');", tblDef.name))
    -- Load columns
    ---@type ISQLiteColumnInfo
    local col
    for cc in tbl_info_st:nrows() do
        col = cc
        col.indexing = {}
        -- Check if primary key has more 4 columns (Flexilite supports max 4 keys in unique index)
        if col.pk > 4 and not tblInfo.multiPKey then
            tblInfo.multiPKey = true

            -----@type IFlexishResultItem
            local msg = {
                type = 'warn',
                message = 'Unique index with more than 4 keys is not supported',
                tableName = tblInfo.table
            }
            table.insert(self.results, msg)
        end
        -- use cid + 1 (i.e. 1..N), as cid starts from 0
        tblInfo.columns[col.cid + 1] = col
        tblInfo.columnCount = tblInfo.columnCount + 1
        tblInfo.columnsByName[col.name] = col
    end
end

---Create properties based on SQLite columns: first iteration
---@param tblInfo ITableInfo
---@param classDef ClassDefData
function SQLiteSchemaParser:initializeProperties(tblInfo, classDef)
    for _, col in ipairs(tblInfo.columns) do
        ---@type PropertyDefData
        local prop = self:sqliteColToFlexiProp(col)

        prop.rules.maxOccurrences = 1
        prop.rules.minOccurrences = tonumber(col.notnull)

        -- clean default values for typical case
        if prop.rules.minOccurrences == 0 and prop.rules.maxOccurrences == 1 then
            prop.rules.minOccurrences = nil
            prop.rules.maxOccurrences = nil
        end

        if col.pk == 1 and not tblInfo.multiPKey then
            -- TODO Handle multiple column PKEY
            prop.index = 'unique'
        end

        -- Default value
        if col.dflt_value then
            if prop.rules.type == 'number' or prop.rules.type == 'integer' or prop.rules.type == 'money' then
                prop.defaultValue = tonumber(col.dflt_value)
            else
                prop.defaultValue = col.dflt_value
            end
        end

        classDef.properties[col.name] = prop

        ---@type table @comment PropertyExtData
        local propXDef = {}
        if not self.propXDefs then
            self.propXDefs = {}
        end
        self.propXDefs[prop] = propXDef;
    end
end

---Load and processes table's indexes
---SQLite may not include primary key index definition in the index list
---and in this case PK definition can be retrieved from column information.
---For consistency, if PK index is missing in pragma index_list, we add extra item,
---with PK information
---@param tblInfo ITableInfo
---@param tblDef ISQLiteTableInfo
function SQLiteSchemaParser:loadIndexDefs(tblInfo, sqliteTblDef)
    ---@type ISQLiteIndexInfo[]
    local idx_list_st = self.db:prepare(string.format("pragma index_list('%s');", sqliteTblDef.name))
    local indexes = {}

    local pk_found = false
    local last_seq = -1
    for v in idx_list_st:nrows() do
        if v.origin == 'pk' then
            -- Primary index
            pk_found = true
        end

        if v.seq > last_seq then
            last_seq = v.seq
        end

        v.cols = {}
        local idx_info_st = self.db:prepare(string.format("pragma index_info('%s');", v.name))
        for idx_col in idx_info_st:nrows() do
            table.insert(v.cols, idx_col)
        end

        table.insert(indexes, v)
    end

    -- Check if primary key index info was included by SQLite
    -- If not, create "artificial" primary key index info
    if not pk_found then
        ---@type ISQLiteIndexInfo
        local pk_def = {}
        pk_def.name = '.' .. sqliteTblDef.name .. '_PK'
        pk_def.cols = {}
        pk_def.origin = 'pk'
        pk_def.partial = 0
        pk_def.unique = 1
        pk_def.seq = last_seq + 1
        table.insert(indexes, pk_def)

        -- Init cols
        local pk_seq = 0
        for nn, cc in pairs(tblInfo.columns) do
            if cc.pk > 0 then
                pk_seq = pk_seq + 1
                ---@type ISQLiteIndexColumnInfo
                local idx_col = {}
                idx_col.name = cc.name
                idx_col.cid = nn
                idx_col.seqno = pk_seq
                pk_def.cols[cc.pk] = idx_col
            end
        end
    end

    tblInfo.indexes = indexes;
    return indexes
end

---@param idx_a ISQLiteIndexInfo
---@param idx_b ISQLiteIndexInfo
local function sortIndexDefsByUniquenessAndColCount(idx_a, idx_b)
    local uniq_a
    if idx_a.origin == 'pk' or idx_a.unique ~= 0 then
        uniq_a = 0
    else
        uniq_a = 10
    end
    local uniq_b
    if idx_b.origin == 'pk' or idx_b.unique ~= 0 then
        uniq_b = 0
    else
        uniq_b = 10
    end

    return uniq_a > uniq_b and #idx_a.cols > #idx_b.cols
end

--- Property indexing priority
local PROP_INDEX_PRIORITY = {
    INDEX = 0,
    UNIQ = 1,
    MKEY1 = 2,
}

--- Applies SQLite index definitions to Flexi properties
---The following cases are handled:
---1) single column unique indexes - accepted as is
---2) single column non-unique indexes on float, integer or date types - added to RTREE index if possible
---3) single column non-unique indexes on text column - accepted as is
---4) one multi column unique (including primary) indexes, with # of columns between 2 and 4,
---used to define multi column index
---5) for other unique
---@param tblInfo ITableInfo
---@param sqliteTblDef ISQLiteTableInfo
---@param classDef ClassDefData
function SQLiteSchemaParser:applyIndexDefs(tblInfo, sqliteTblDef, classDef)
    -- First, sort by uniqueness and number of columns
    table.sort(tblInfo.indexes, sortIndexDefsByUniquenessAndColCount)

    local multi_key_idx_applied = false

    --[[
    Keeps list of all columns that are already indexed. Key is column name,
    value corresponds to index type, based on priority
    index = 0
    rtree = 1
    fts = 2
    unique = 3
    first_in_mkey = 4 -- first column in multi key unique index
    ]]
    ---@type table<string, number>
    local indexed_cols = {}

    -- Second, process sorted indexes
    for _, vv in pairs(tblInfo.indexes) do
        ---@type ISQLiteIndexInfo
        local idx_def = vv
        -- Check if index is supported by Flexilite
        if idx_def.partial ~= 0 then
            print(ansicolors(string.format('%%{yellow}WARN: Partial index %s is not supported. Skipping.%%{reset}', idx_def.name)))
            goto end_of_loop
        elseif idx_def.origin ~= 'pk' and idx_def.origin ~= 'c' then
            print(ansicolors(string.format('%%{yellow}WARN: Unknown origin "%s" of index %s. Skipping.%%{reset}', idx_def.origin, idx_def.name)))
            goto end_of_loop
        elseif #idx_def.cols == 0 then
            print(ansicolors(string.format('%%{yellow}WARN: Index "%s" does not have any columns. Skipping.%%{reset}', idx_def.name)))
            goto end_of_loop
        end

        -- Primary or secondary index -> process
        local col_name = idx_def.cols[1].name
        local propDef = classDef.properties[col_name]
        assert(propDef)

        if #idx_def.cols == 1 then

            if idx_def.unique ~= 0 then
                -- Unique index on single column? Apply as is unless it is defined as 1st column in
                -- unique multi key index
                if not indexed_cols[col_name] or indexed_cols[col_name] < PROP_INDEX_PRIORITY.UNIQ then
                    indexed_cols[col_name] = PROP_INDEX_PRIORITY.UNIQ
                    propDef.index = 'unique'
                end
            else
                -- Check if this column was not yet included into other indexes. If not, check if column can be added to RTREE index
                -- If no, create a regular non unique index
                if indexed_cols[col_name] then
                    goto end_of_loop
                end

                propDef.index = 'index'
                indexed_cols[col_name] = PROP_INDEX_PRIORITY.INDEX
            end
        elseif idx_def.unique ~= 0 then
            if multi_key_idx_applied then
                print(ansicolors(string.format([[%%{yellow}WARN: More than 1 multi column unique index [%s] found.
                Currently Flexilite can support only one multi column unique index%%{reset}]], idx_def.name)))
                goto end_of_loop
            end

            if #idx_def.cols > 4 then
                print(ansicolors(string.format([[%%{yellow}WARN: Index [%s] has %d columns.
                 Maximum 4 columns is supported by Flexilite%%{reset}]], idx_def.name, #idx_def.cols)))
                goto end_of_loop
            end

            -- Init multi key unique index
            if not classDef.indexes then
                classDef.indexes = {}
            end
            local mkey_idx = {}
            classDef.indexes.multiKeyIndexing = mkey_idx

            for _, cc in ipairs(idx_def.cols) do
                table.insert(mkey_idx, { text = cc.name })
            end
            indexed_cols[idx_def.cols[1].name] = PROP_INDEX_PRIORITY.MKEY1;

            multi_key_idx_applied = true
        else
            if not indexed_cols[col_name] then
                indexed_cols[col_name] = PROP_INDEX_PRIORITY.INDEX
                propDef.index = 'index'
            end

            propDef.index = 'index'
            -- Multi column non unique indexes are ignored
            print(ansicolors(string([[%%{yellow}WARN: Only first column of multi-column, non-unique index [%s] will be indexed%%{reset}]],
                    idx_def.name)))
            goto end_of_loop
        end

        :: end_of_loop ::
    end
end

--[[
     Processes indexes specification using following rules:
     1) primary and unique indexes on single columns are processed as is
     2) multi column (composite) unique indexes are supported if number of columns is 2..4.
     3) partial indexes and composite unique indexes with column count > 4 are not supported. Warning will be generated

     4) DESC clause in index definition is ignored. Warning will be generated.
     5) non-unique indexes on text columns are converted to FTS indexes
     6) all numeric and datetime columns included into non-unique indexes (both single and multi column)
     are considered to participate in RTree index. Maximum 5 columns can be RTree-indexed. Priority is given
     7) Columns from non-unique indexes that were not included into FTS nor RTree indexes will be indexed. Note:
     for multi-column indexes only first columns in index definitions will be processed.
     8) All columns from non-unique indexes that were not included into FTS, RTree or regular indexes will NOT be indexed
     Warning will be generated

     Applies some guessing about role of columns based on their indexing and naming
     The following rules are applied:
     1) primary not autoincrement or unique non-text column gets role "uid"
     2) unique text column(s) get roles "code" and "name".
     3) If unique column name ends with '*Code'
     or its max length is shortest among other unique text columns, it gets role "code"
     4) If unique column name ends with "*Name", it gets role "name",

     Loads all metadata for the SQLite table (columns, indexes, foreign keys)
     Builds complete ITableInfo and returns promise for it
     ]]
---@param sqliteTblDef ISQLiteTableInfo
---@return ITableInfo
function SQLiteSchemaParser:loadTableInfo(sqliteTblDef)
    -- Init resulting dictionary
    ---@type ClassDefData
    local classDef = {
        properties = {},
        specialProperties = {}
    }

    self.outSchema[sqliteTblDef.name] = classDef

    ---@type ITableInfo
    local tblInfo = {
        -- Table name
        table = sqliteTblDef.name,

        -- Number of columns
        columnCount = 0,

        -- List of columns, by SQLite "cid" value
        columns = {},

        columnsByName = {},

        -- List of incoming foreign keys (other tables refer to this one)
        inFKeys = {},

        -- List of outgoing foreign keys (references to other tables)
        outFKeys = {},

        -- true if table is many2many link table
        manyToManyTable = false,

        -- true if composite primary key
        multiPKey = false
    }
    table.insert(self.tableInfo, tblInfo)

    self:loadTableColumns(tblInfo, sqliteTblDef)

    self:initializeProperties(tblInfo, classDef)

    local indexes = self:loadIndexDefs(tblInfo, sqliteTblDef)
    self:applyIndexDefs(tblInfo, sqliteTblDef, classDef)

    tblInfo.supportedIndexes = {}
    -- Checking if there non-supported indexes
    for _, idx in ipairs(indexes) do
        if idx.partial == 0 and (string.lower(idx.origin) == 'c' or string.lower(idx.origin) == 'pk') then
            table.insert(tblInfo.supportedIndexes, idx)
        else
            ---@type IFlexishResultItem
            local msg = {
                type = 'warn',
                message = string.format('Index %s is not supported', idx.name),
                tableName = tblInfo.table,
            }
            table.insert(self.results, msg)
        end
    end

    return tblInfo;
end

-- Loads and processes foreign key definitions
---@param tblInfo ITableInfo
function SQLiteSchemaParser:processForeignKeys(tblInfo)
    -- Process foreign keys
    ---@type ISQLiteForeignKeyInfo[]
    local fkInfo = {}
    for v in self.db:nrows(string.format(
            "pragma foreign_key_list('%s');", tblInfo.table)) do
        table.insert(fkInfo, v)
    end

    -- TODO
    -----@param fkey ISQLiteForeignKeyInfo
    --local function isTheSameFKey(fkey, id)
    --    return fkey.id == id
    --end

    if #fkInfo > 0 then
        for i, fk in ipairs(fkInfo) do
            fk.srcTable = tblInfo.table
            fk.processed = false
            table.insert(tblInfo.outFKeys, fk)

            local outTbl = self:findTableInfoByName(fk.table)
            if not outTbl then
                table.insert(self.results, {
                    type = 'error',
                    message = string.format("Table [%s] specified in FKEY not found", fk.table),
                    tableName = tblInfo.table
                })
                break
            end

            table.insert(outTbl.inFKeys, fk)
        end
    end
end

---@param tbl ITableInfo
---@param idx ISQLiteIndexInfo
function SQLiteSchemaParser:getIndexColumnNames(tbl, idx)
    local result = {}
    for i, c in ipairs(idx.columns) do
        table.insert(result, tbl.columns[c.cid + 1].name)
    end
    return table.concat(result, ',')
end

---@param classDef ClassDef
---@param prop PropertyDef
---@return string
function SQLiteSchemaParser:findPropName(classDef, prop)
    for name, p in pairs(classDef.properties) do
        if p == prop then
            return name
        end
    end

    return nil
end

-- Try to find matching properties for special purposes (IClassDef.specialProperties)
---@param tblInfo ITableInfo
---@param classDef ClassDef
function SQLiteSchemaParser:processSpecialProps(tblInfo, classDef)

    -- This dictionary defines weights for property types to be used when guessing for special properties
    local propTypeMetadata = {
        ['integer'] = 10000 + 0,
        ['number'] = 10000 + 1,
        ['money'] = 10000 + 1,
        ['text'] = 10000 + 2, -- leave range for text's maxLength
        ['date'] = 10000 + 258,
        ['timespan'] = 10000 + 259,
        ['boolean'] = 10000 + 260,
        ['binary'] = 10000 + 261,
    }

    -- Calculates weight of column based on type and index
    ---@param prop PropertyDef
    ---@return number
    local function getColumnWeight(prop)
        local weight = propTypeMetadata[prop.rules.type]
        if not weight then
            return 100000
        end

        if prop.rules.maxLength then
            weight = weight + prop.rules.maxLength
        end

        --        local prop = classDef.properties[tblInfo.columns[A.columns[1].cid + 1].name]
        -- check if this property is indexed
        if prop.index == 'index' or prop.index == 'fulltext' or prop.index == 'range' then
            weight = weight - 5000
        elseif prop.index == 'unique' then
            weight = weight - 10000
        end

        return weight
    end

    -- get all not-null props, sorted by their weight
    local notNullPropsMap = table.filter(classDef.properties, function(p)
        return p.rules.minOccurrences and p.rules.minOccurrences > 0
    end)

    local notNullProps = tablex.values(notNullPropsMap)

    if #notNullProps == 0 then
        return
    end

    table.sort(notNullProps,
            function(A, B)
                local aw = getColumnWeight(A)
                local bw = getColumnWeight(B)
                return aw < bw
            end)

    -- Wild guessing about special properties
    -- uid - non autoinc primary key or single column unique index (shortest, if there are few unique single column indexes)
    if notNullProps[1].index == 'unique' then
        local propName = self:findPropName(classDef, notNullProps[1])
        classDef.specialProperties.uid = { text = propName }
        table.remove(notNullProps, 1)
    end

    -- code - next (after UID) unique index on single required text column (or column named 'code')
    if notNullProps[1] and notNullProps[1].index == 'unique' and notNullProps[1].rules.type == 'text' then
        local propName = self:findPropName(classDef, notNullProps[1])
        classDef.specialProperties.code = { text = propName }
        table.remove(notNullProps, 1)
    end

    -- autoUuid: binary(16), unique index, required or column 'guid', 'uuid'
    if notNullProps[1] and notNullProps[1].index == 'unique' and notNullProps[1].rules.type == 'binary'
            and notNullProps[1].rules.maxLength == 16 then
        local propName = self:findPropName(classDef, notNullProps[1])
        classDef.specialProperties.name = { text = propName }
        table.remove(notNullProps, 1)
    end

    -- remove all non text columns at the beginning
    while #notNullProps > 0 do
        local tt = notNullProps[1].rules.type
        if tt ~= 'integer' and tt ~= 'number' and tt ~= 'money' then
            break
        end
        table.remove(notNullProps, 1)
    end

    -- name - next (after Code) unique text index or shortest required indexed text column (or 'name')
    if notNullProps[1] and ((notNullProps[1].index == 'unique' or notNullProps[1].index == 'index') and notNullProps[1].rules.type == 'text')
            or (#notNullProps == 1 and notNullProps[1].rules.type == 'text') then
        local propName = self:findPropName(classDef, notNullProps[1])
        classDef.specialProperties.name = { text = propName }
        table.remove(notNullProps, 1)
    end

    -- if there is only text property in the class, treat it as name
    if not classDef.specialProperties.name then
        local txtProp, txtPropName = nil, nil
        for name, p in pairs(classDef.properties) do
            if p.rules.type == 'text' then
                if txtProp then
                    -- not the first one -> reset and stop
                    txtProp = nil
                    break
                end
                txtProp = p
                txtPropName = name
            end
        end
        if txtProp then
            classDef.specialProperties.name = { text = txtPropName }
        end
    end

    if #notNullProps == 0 then
        return
    end

    ---@param colNames string[]
    ---@param type string
    ---@return table | nil
    local function findReqCol(colNames, types)
        if type(types) ~= 'table' then
            types = { types }
        end
        for name, p in pairs(classDef.properties) do
            for i, colName in ipairs(colNames) do
                if string.lower(name) == string.lower(colName) then
                    for _, tt in ipairs(types) do
                        if p.rules.type == tt then
                            return { text = colName }
                        end
                    end
                end
            end
        end

        return nil
    end

    -- description - next (after Name) required text column (or 'description')
    for i, p in ipairs(notNullProps) do
        if p.rules.type == 'text' then
            local propName = self:findPropName(classDef, p)
            classDef.specialProperties.description = { text = propName }
            table.remove(notNullProps, i)
            break
        end
    end
    if not classDef.specialProperties.description then
        classDef.specialProperties.description = findReqCol({ 'description' }, 'text')
    end

    -- owner - text or integer column named 'owner', 'created_by', 'createdby', 'assignedto'
    classDef.specialProperties.owner = findReqCol({ 'owner', 'created_by', 'createdby', 'assignedto', 'assigned_to' }, { 'text', 'integer' })

    -- createTime - date/datetime required column 'created', 'create_date', 'insert_date'
    classDef.specialProperties.createTime = findReqCol({ 'createtime', 'created', 'create_time', 'create_date', 'createdate' }, { 'time', 'date' })

    -- updateTime - date/datetime required column 'last_changed', 'update_date', 'updated', 'last_modified', 'modify_date', 'change_date'
    classDef.specialProperties.updateTime = findReqCol({ 'updatetime', 'updated', 'update_time', 'update_date', 'updatedate', 'last_changed', 'lastchanged', 'last_updated', 'lastupdated', 'last_modified', 'lastmodified' }, { 'time', 'date' })

    -- If no special properties were defined, clean up the attribute. No need to carry on this luggage
    local empty = true
    for _, _ in pairs(classDef.specialProperties) do
        empty = false
        break
    end
    if empty then
        classDef.specialProperties = nil
    end
end

-- Processes foreign key definitions
--Converts FKEY definitions to 'enum' properties and adds comments to classes for
--future schema 1refactoring
---@param tblInfo ITableInfo
function SQLiteSchemaParser:processReferences(tblInfo)
    local classDef = self.outSchema[tblInfo.table]

    -- get table primary key
    local pkCols = table.filter(tblInfo.columns, function(cc)
        return cc.pk > 0
    end)

    --[[ TODO uses logic below for creating suggestion comments for the class
         Process foreign keys. Defines reference properties.
         There are following cases:
         1) normal 1:N, (1 is defined in inFKeys, N - in outFKeys). Reverse property is created in counterpart class
         This property is created as enum, reversed property is also created as enum
         2) mixin 1:1, when outFKeys column is primary column
         This case is reported but not processed, as complete implementation will impose many complications in the class definitions and further data import.

         3) many-to-many M:N, via special table with 2 columns which are foreign keys to other table(s)
         4) primary key is multiple, and first column in primary key is foreign
         key to another table. This will create a master reference property.
    ]]

    -- Detect many2many case
    --local many2many = false
    --if tblInfo.columnCount == 2 and #tblInfo.outFKeys == 2
    --and #tblInfo.inFKeys == 1 then
    --    --[[
    --Candidate for many-to-many association
    --Full condition: both columns are required
    --Both columns are in outFKeys
    --Primary key is on columns A and B
    --There is another non unique index on column B
    --]]
    --    many2many = table.isEqual(table.map(tblInfo.columns, 'name'), table.map(tblInfo.outFKeys, 'from'))
    --end
    --
    --if many2many then
    --    classDef.storage = 'flexi-rel'
    --    classDef.storageFlexiRel.master = {
    --        ownProperty = { text = tblInfo.outFKeys[1].from },
    --        refClass = { text = tblInfo.outFKeys[1].table },
    --        refProperty = { text = tblInfo.outFKeys[1].to }
    --    }
    --
    --    -- TODO ???
    --    classDef.storageFlexiRel.master = {
    --        ownProperty = { text = tblInfo.outFKeys[2].from },
    --        refClass = { text = tblInfo.outFKeys[2].table },
    --        refProperty = { text = tblInfo.outFKeys[2].to }
    --    }
    --
    --    -- No need to process indexing as this class will be used as a virtual table with no data
    --    return;
    --end
    --
    ---- Detect "mixin"
    --local extCol, extColIdx = table.find(tblInfo.outFKeys, function(fk)
    --    return pkCols and #pkCols == 1 and pkCols[1].name == fk.from
    --end )
    --
    --if extCol then
    --    -- set mixin property
    --    classDef.properties[extCol.table] = { rules = { type = 'mixin' }, refDef = { classRef = { text = extCol.table } } }
    --    --classDef.properties[pkCols[1].name] = { rules = { type = 'mixin' }, refDef = { classRef = { text = extCol.table } } }
    --    extCol.processed = true
    --    table.remove(tblInfo.outFKeys, extColIdx)
    --    return
    --end

    --[[
         Processing what has left and create reference properties
         Reference property gets name based on name of references table
         and, optionally, 'from' column, so for relation between Order->OrderDetails by OrderID
         (for both tables) 2 properties will be created:
         a) in Orders: OrderDetails
         b) in OrderDetails: Order (singular form of Orders)
         In case of name conflict, ref property gets fully qualified name:
         Order_OrderID, OrderDetails_OrderID

         'from' columns for outFKeys are converted to computed properties: they accept input value,
         treat it as uid property of master class and don't get stored.
    ]]
    for _, fk in ipairs(tblInfo.outFKeys) do
        -- N : 1
        if not fk.processed then
            local cc = classDef.properties[fk.from]
            cc.rules.type = 'enum'

            --local pp = {
            --    rules = {
            --        type = 'enum',
            --        minOccurrences = cc.rules.minOccurences,
            --        maxOccurrences = bits.lshift(1, 31) - 1
            --    }
            --}
            --local propName = fk.table -- FIXME Pluralize
            ---- Guess reference/enum property name
            --if classDef.properties[propName] then
            --    propName = string.format("%s_%s", propName, fk.from)
            --end

            cc.enumDef = {
                classRef = { text = fk.table }
            }

            table.insert(self.referencedTableNames, fk.table)

            --classDef.properties[propName] = pp
            -- TODO set on update, on delete
            fk.processed = true
        end
    end

    --for i, fk in ipairs(tblInfo.inFKeys) do
    --    -- 1 : N
    --    -- TODO
    --end

end

-- Enforces class to have ID and Name special properties
-- This is needed for FKEY imported as 'enum' properties
---@param tableName string
---@return nil
function SQLiteSchemaParser:enforceIdAndNameProps(tableName)
    local tblInfo = self:findTableInfoByName(tableName)
    local classDef = self.outSchema[tblInfo.table]
    if not classDef.specialProperties.uid then
        -- TODO Any property
    end

    if not classDef.specialProperties.name then
        -- TODO Any text property
    end
end

---@param tblInfo ITableInfo
---@return ClassDef
function SQLiteSchemaParser:processFlexiliteClassDef(tblInfo)
    local classDef = self.outSchema[tblInfo.table]

    self:processReferences(tblInfo)
    self:processSpecialProps(tblInfo, classDef)
    self:detectMixinCandidate(tblInfo, classDef)

    return classDef
end

-- Check required fields. Candidates for name, description, nonUniqueId, createTime, updateTime,
-- owner

--[[
     Loads schema from SQLite database
     and parses it to Flexilite class definition
]]
---@param outJSON string @comment absolute path to JSON file where schema will be saved
function SQLiteSchemaParser:ParseSchema(outJSON)
    self.outSchema = {}
    self.tableInfo = {}

    local stmt = self.db:prepare("select * from sqlite_master where type = 'table' and name not like 'sqlite%';")

    ---@type ISQLiteTableInfo
    for item in stmt:nrows() do
        print(ansicolors(string.format('Processing: %%{white}%s%%{reset}', item.name)))
        self:loadTableInfo(item)
    end

    for tableName, tblInfo in pairs(self.tableInfo) do
        self:processForeignKeys(tblInfo)
    end

    for tableName, tblInfo in pairs(self.tableInfo) do
        self:processFlexiliteClassDef(tblInfo)
    end

    for idx, tblName in ipairs(self.referencedTableNames) do
        self:enforceIdAndNameProps(tblName)
    end

    self:processMany2ManyRelations()

    return self.outSchema
end

--[[ Detects if class is mixin, i.e. its primary key is the foreign key to another table.
In that case references class is added as mixin property named 'base'.
Definition of mixin property will also get name of udid (user defined ID) column to be used for future data import
]]
---@param tblInfo ITableInfo
---@param classDef ClassDefData
function SQLiteSchemaParser:detectMixinCandidate(tblInfo, classDef)

    ---@param idx ISQLiteIndexInfo
    local function isPKey(idx)
        return idx.origin == 'pk'
    end

    -- Get primary key definition
    local pkIdx = tablex.find_if(tblInfo.indexes, isPKey)

    assert(pkIdx)

    ---@type ISQLiteIndexInfo
    local pk = tblInfo.indexes[pkIdx]

    -- Only single column primary key is supported
    if #pk > 1 then
        return
    end

    ---@param fkeyDef ISQLiteForeignKeyInfo
    local function isOutFKeyMatchingPKey(fkeyDef)
        return fkeyDef.from == pk.cols[1].name
    end

    -- Get out foreign key matching primary key definition
    local fk = table.filter(tblInfo.outFKeys, isOutFKeyMatchingPKey)

    if #fk ~= 1 or not fk[1] then
        return
    end

    -- Definitely, mixin
    local propDef = classDef.properties[fk[1].from]
    assert(propDef)

    if propDef.enumDef then
        propDef.enumDef.mixin = true
        print(ansicolors(string.format('%%{yellow}Table %s was detected as a mixin based on %s.%%{reset}',
                tblInfo.table, fk[1].table)))
    end
end

return SQLiteSchemaParser
