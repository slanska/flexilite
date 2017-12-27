---
--- Created by slanska.
--- DateTime: 2017-11-18 12:06 PM
---

local bits = type(jit) == 'table' and require('bit') or require('bit32')
local class = require 'pl.class'
local SQLiteSchemaParser = class()
local tablex = require 'pl.tablex'

table.find = function(tbl, func)
    for k, v in pairs(tbl) do
        if func(v, k) then
            return v, k
        end
    end

    return nil, nil
end

table.filter = function(tbl, func)
    local result = {}
    for i, v in pairs(tbl) do
        if func(v) then
            result[i] = v
        end
    end

    return result
end

table.map = function(tbl, funcOrName)
    local result = {}
    local isFunc = type(func) == 'function'
    for i, v in pairs(tbl) do
        if isFunc then
            table.insert(result, isFunc(v, tbl, i))
        else
            table.insert(result, v[funcOrName])
        end
    end
    return result
end

table.isEqual = function(A, B)
    if #A ~= #B then
        return false
    end

    for i, v in ipairs(A) do
        if v ~= B[i] then
            return false
        end
    end

    return true
end

---@param db sqlite3.Database
function SQLiteSchemaParser:_init(db)
    -- ClassDefCollection
    self.outSchema = {}

    -- ITableInfo[]
    self.tableInfo = {}

    --FlexishResults
    self.results = {}

    self.db = db

    -- List of table names that are references by other tables
    -- Needed to enforce id and name special properties
    self.referencedTableNames = {}
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

    ['ntext'] = { type = 'binary', maxLength = bits.lshift(1, 31) - 1 },

    ['integer'] = { type = 'integer' },
    ['smallint'] = { type = 'integer', minValue = -32768, maxValue = 32767 },
    ['tinyint'] = { type = 'integer', minValue = 0, maxValue = 255 },
}

---@param sqliteCol ISQLiteColumn
---@return IClassPropertyDef
function SQLiteSchemaParser:sqliteColToFlexiProp(sqliteCol)
    local p = { rules = { type = 'any' } }

    if sqliteCol.type ~= nil then
        -- Parse column type to extract length and type
        local _, _, tt, ll = string.find(sqliteCol.type, '^%s*(%a+)%s*%(%s*(%d+)%s*%)%s*$')
        if tt and ll then
            tt = string.lower(tt)
            local rr = tablex.deepcopy( sqliteTypesToFlexiTypes[tt])
            if rr then
                p.rules = rr
                p.rules.maxLength = tonumber(ll)
            end
        else
            local rr = tablex.deepcopy( sqliteTypesToFlexiTypes[string.lower(sqliteCol.type)])
            if rr then
                p.rules = rr
            end
        end
    end

    return p
end

-- Returns unique property name based on suggestedPropName. If possible, uses suggestedPropName as result
---@param tblInfo ISQLiteTableInfo
---@param classDef IClassDef
---@param suggestedPropName string
---@return string
function SQLiteSchemaParser:getUniqPropName(tblInfo, classDef, suggestedPropName)

end

--[[
Iterates over list of tables and tries to find candidates for many-to-many relation tables.
Canonical conditions:
1) table must have only 2 columns (A & B)
2) table must have primary index on both columns
3) Both columns must be foreign keys to some tables
4) there is an index on column B (this is optional, not required)

If conditions 1-4 are met, this table is considered as a many-to-many list.
Foreign key info in SQLite comes from detail/linked table, so it is either N:1 or 1:1
]]
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

    for i, it in ipairs(self.tableInfo) do
        if it.columnCount == 2 then
            -- TODO
        end
    end
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
---@param tblDef ISQLiteTableInfo
---@return ITableInfo
function SQLiteSchemaParser:loadTableInfo(tblDef)
    -- Init resulting dictionary
    -- IClassDefinition
    local classDef = {
        properties = {},
        specialProperties = {}
    }

    self.outSchema[tblDef.name] = classDef

    -- ITableInfo
    local tblInfo = {
        -- Table name
        table = tblDef.name,

        -- Number of columns
        columnCount = 0,

        -- List of columns, by SQLite "cid" value
        columns = {},

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

    local tbl_info_st = self.db:prepare(string.format("pragma table_info ('%s');", tblDef.name))
    -- Load columns
    for col in tbl_info_st:nrows() do
        if col.pk > 1 and not tblInfo.multiPKey then
            tblInfo.multiPKey = true

            -- IFlexishResultItem
            local msg = {
                type = 'warn',
                message = 'Multi-column primary key is not supported',
                tableName = tblInfo.table
            }
            table.insert(self.results, msg)
        end
        tblInfo.columns[col.cid + 1] = col
        tblInfo.columnCount = tblInfo.columnCount + 1
    end

    -- Create properties
    for idx, col in ipairs(tblInfo.columns) do
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

        if col.dflt_value then
            local defVal = col.dflt_value
            if prop.rules.type == 'number' or prop.rules.type == 'integer' or prop.rules.type == 'money' then
                defVal = tonumber(defVal)
            end
            prop.defaultValue = defVal
        end

        classDef.properties[col.name] = prop
    end

    -- Process indexes
    local deferredIdxCols = {}
    -- ISQLiteIndexInfo[]
    local idx_list_st = self.db:prepare(string.format("pragma index_list('%s')", tblDef.name))
    local indexes = {}
    for v in idx_list_st:nrows() do
        table.insert(indexes, v)
    end
    -- Check if primary key is included into list of indexes
    local pkIdx = table.find(indexes, function(ix)
        return ix.origin == 'pk'
    end)

    if not pkIdx then
        local pkCol = table.find(tblInfo.columns, function(cc)
            return cc.pk == 1
        end)
        if pkCol then
            table.insert(indexes, {
                seq = indexes.length,
                name = 'pk',
                unique = 1,
                origin = 'pk',
                partial = 0,
                columns = { {
                    seq = 0,
                    cid = pkCol.cid,
                    name = pkCol.name
                } }
            })
        end
    end

    tblInfo.indexes = indexes;

    tblInfo.supportedIndexes = table.filter(indexes, function(idx)
        return idx.partial == 0 and (string.lower(idx.origin) == 'c' or string.lower(idx.origin) == 'pk');
    end)

    -- Process all supported indexes
    for i, idx in pairs(tblInfo.supportedIndexes) do
        idx.columns = idx.columns or {};
        local idx_info_st = self.db:prepare(string.format("pragma index_info('%s');", idx.name))
        local cc = {}
        for v in idx_info_st:nrows() do
            table.insert(cc, v)
        end
        table.insert(deferredIdxCols, cc)
    end

    -- Process index columns
    for ii, idxCols in ipairs(deferredIdxCols) do
        for i, idxCol in ipairs(idxCols) do
            table.insert(tblInfo.supportedIndexes[ii].columns, idxCol)
        end
    end

    return tblInfo;
end

-- Loads and processes foreign key definitions
---@param tblInfo ITableInfo
function SQLiteSchemaParser:processFKeys(tblInfo)
    -- Process foreign keys
    local fkInfo = {}
    for v in self.db:nrows(string.format("pragma foreign_key_list('%s')", tblInfo.table)) do
        table.insert(fkInfo, v)
    end

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

---@param classDef IClassDef
---@param prop IPropertyDef
---@return string
function SQLiteSchemaParser:findPropName( classDef, prop)
    for name, p in pairs(classDef.properties) do
        if p == prop then
            return name
        end
    end

    return nil
end

-- Try to find matching properties for special purposes (IClassDef.specialProperties)
---@param tblInfo ITableInfo
---@param classDef IClassDef
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
    ---@param prop IPropertyDef
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

    table.sort(notNullProps,
    function(A, B)
        local aw = getColumnWeight(A)
        local bw = getColumnWeight(B)
        return aw < bw
    end)

    if #notNullProps == 0 then
        return
    end

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

    ---@param colNames table @of string
    ---@param type string
    local function findReqCol(colNames, types)
        if type(types) ~= 'table' then
            types = { types }
        end
        local result = table.find(classDef.properties, function(p, name)
            for i, colName in ipairs(colNames) do
                if string.lower(name) == string.lower(colName) then
                    for _, tt in ipairs(types) do
                        if p.rules.type == tt then
                            return true
                        end
                    end
                end
            end

            return false
        end )

        return result
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
    end )

    --[[ TODO uses logic below for creating suggestion comments for the class
         Process foreign keys. Defines reference properties.
         There are following cases:
         1) normal 1:N, (1 is defined in inFKeys, N - in outFKeys). Reverse property is created in counterpart class
         This property is created as enum, reversed property is also created as enum
         2) mixin 1:1, when outFKeys column is primary column
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
    for i, fk in ipairs(tblInfo.outFKeys) do
        -- N : 1
        if not fk.processed then
            local cc = classDef.properties[fk.from]
            cc.rules.type = 'enum'

            --local pp = {
            --    rules = {
            --        type = 'enum',
            --        minOccurences = cc.rules.minOccurences,
            --        maxOccurences = bits.lshift(1, 31) - 1
            --    }
            --}
            --local propName = fk.table -- FIXME Pluralize
            ---- Guess reference/enum property name
            --if classDef.properties[propName] then
            --    propName = string.format("%s_%s", propName, fk.from)
            --end

            cc.refDef = {
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
---@return IClassDef
function SQLiteSchemaParser:processFlexiliteClassDef(tblInfo)
    local classDef = self.outSchema[tblInfo.table]

    self:processReferences(tblInfo)

    -- Set indexing
    self:processUniqueNonTextIndexes(tblInfo, classDef)
    self:processUniqueTextIndexes(tblInfo, classDef)
    self:processUniqueMultiColumnIndexes(tblInfo, classDef)
    self:processNonUniqueIndexes(tblInfo, classDef)
    self:processSpecialProps(tblInfo, classDef)

    return classDef
end

---@param tblInfo ITableInfo
---@param classDef IClassDefinition
function SQLiteSchemaParser:processNonUniqueIndexes(tblInfo, classDef)
    local nonUniqueIndexes = table.filter(tblInfo.supportedIndexes, function(idx)
        return idx.unique ~= 1
    end )

    -- Pool of full text columns
    local ftsCols = { 'X1', 'X2', 'X3', 'X4' }

    -- Pool of rtree columns
    local rtCols = { 'A', 'B', 'C', 'D', 'E' }

    for i, idx in ipairs(nonUniqueIndexes) do
        local col = tblInfo.columns[idx.columns[1].cid + 1]
        local prop = classDef.properties[col.name]

        if prop.rules.type == 'text' then
            if not prop.index then
                -- No available full text indexes or text is too short
                if #ftsCols == 0 or prop.rules.maxLength <= 40 then
                    prop.index = 'index'
                else
                    local ftsCol = table.remove(ftsCols)
                    classDef.fullTextIndexing = classDef.fullTextIndexing or {}
                    classDef.fullTextIndexing[ftsCol] = { text = col.name }
                    prop.index = 'fulltext'
                end
            end
        elseif prop.rules.type == 'integer' or prop.rules.type == 'number'
        or prop.rules.type == 'datetime' then
            if not prop.index then
                if #rtCols == 0 then
                    prop.index = 'index'
                else
                    local rtCol = table.remove(rtCols)
                    classDef.rangeIndexing = classDef.rangeIndexing or {}
                    classDef.rangeIndexing[rtCol .. '0'] = { text = col.name, }
                    classDef.rangeIndexing[rtCol .. '1'] = { text = col.name }
                    prop.index = 'range'
                end
            end
        else
            prop.index = 'index'
        end
    end
end

---@param tblInfo ITableInfo
function SQLiteSchemaParser:processUniqueMultiColumnIndexes(tblInfo, classDef)
    local uniqMultiIndexes = table.filter(tblInfo.supportedIndexes, function(idx)
        return #idx.columns > 1 and idx.unique == 1 and idx.partial == 0
    end)

    for i, idx in ipairs(uniqMultiIndexes) do
        if #idx.columns > 4 then
            local msg = string.format( "Index [%s] by %s is ignored as multi-column unique indexes with more than 4 columns are not supported by Flexilite",
            idx.name, self:getIndexColumnNames(tblInfo, idx))
            table.insert(self.results, {
                type = 'warn',
                message = msg,
                tableName = tblInfo.table })
        else
            classDef.indexes = classDef.indexes or {}
            classDef.indexes[idx.name] = {
                type = 'unique',
                properties = {}
            }
            for i, cc in ipairs(idx.columns) do
                classDef.indexes[idx.name].properties[i] = { text = cc.name }
            end
        end
    end
end

---@param tblInfo ITableInfo
---@param classDef IClassDefinition
function SQLiteSchemaParser:processUniqueNonTextIndexes(tblInfo, classDef)
    local uniqOtherIndexes = table.filter(tblInfo.supportedIndexes, function(idx)
        local tt = classDef.properties[tblInfo.columns[idx.columns[1].cid + 1].name].rules.type
        return #idx.columns == 1 and idx.unique == 1 and (tt == 'integer' or tt == 'number' or tt == 'datetime'
        or tt == 'binary')
    end )

    table.sort(uniqOtherIndexes,
    function(A, B)
        if not A or not B then
            return 0
        end

        local function getTypeWeight(item)
            local result = classDef.properties[tblInfo.columns[item.columns[1].cid + 1].name].rules.type
            if result == 'integer' then
                return 0
            end
            if result == 'number' then
                return 1
            end
            if result == 'binary' then
                return 2
            end
            return 3
        end

        local v1 = getTypeWeight(A)
        local v2 = getTypeWeight(B)
        return v1 < v2
    end )
end

-- Check required fields. Candidates for name, description, nonUniqueId, createTime, updateTime,
-- owner

---@param tblInfo ITableInfo
---@param classDef IClassDefinition
function SQLiteSchemaParser:processUniqueTextIndexes(tblInfo, classDef)
    --[[
             Split all indexes into the following categories:
         1) Unique one column, by text column: special property and unique index, sorted by max length
         2) Unique one column, date, number or integer: special property and unique index, sorted by type
         - with integer on top
         3) Unique multi-column indexes: currently not supported
         4) Non-unique: only first column gets indexed. Text - full text search or index. Numeric types
         - RTree or index
    ]]
    local uniqTxtIndexes = table.filter(tblInfo.supportedIndexes, function(idx)
        return #idx.columns == 1 and idx.unique == 1
    end )
end

--[[
     Loads schema from SQLite database
     and parses it to Flexilite class definition
     Returns promise which resolves to dictionary of Flexilite classes
]]
function SQLiteSchemaParser:parseSchema()
    self.outSchema = {}
    self.tableInfo = {}

    local stmt, errMsg = self.db:prepare("select * from sqlite_master where type = 'table' and name not like 'sqlite%';")
    for item in stmt:nrows() do
        self:loadTableInfo(item)
    end

    for tableName, tblInfo in pairs(self.tableInfo) do
        self:processFKeys(tblInfo)
    end

    for tableName, tblInfo in pairs(self.tableInfo) do
        self:processFlexiliteClassDef(tblInfo)
    end

    for idx, tblName in ipairs(self.referencedTableNames) do
        self:enforceIdAndNameProps(tblName)
    end

    return self.outSchema
end

return SQLiteSchemaParser