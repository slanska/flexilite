---
--- Created by slanska.
--- DateTime: 2017-11-18 12:06 PM
---

local bits = require 'bit32'

local SQLiteSchemaParser = {}

table.find = function(tbl, func)
    for i, v in pairs(tbl) do
        if func(v) then
            return v, i
        end
    end

    return nil, -1
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
function SQLiteSchemaParser:new(db)
    local result = {
        -- ClassDefCollection
        outSchema = {},

        -- ITableInfo[]
        tableInfo = {},

        --FlexishResults
        results = {},

        db = db,
    }

    setmetatable(result, self)
    self.__index = self

    return result
end

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

    ['blob'] = { type = 'binary', subtype = 'image' },
    ['binary'] = { type = 'binary', subtype = 'image' },
    ['varbinary'] = { type = 'binary', subtype = 'image' },
    ['image'] = { type = 'binary', subtype = 'image' },

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
            local rr = sqliteTypesToFlexiTypes[tt]
            if rr then
                p.rules = rr
                p.rules.maxLength = tonumber(ll)
            end
        else
            local rr = sqliteTypesToFlexiTypes[string.lower(sqliteCol.type)]
            if rr then
                p.rules = rr
            end
        end
    end

    return p
end

--[[
Iterates over list of tables and tries to find candidates for many-to-many relation tables.
Canonical conditions:
1) table should have only 2 columns (A & B)
2) table should have primary index on both columns (A and B)
3) Both columns are foreign keys to some tables
4) there is an index on column B (optional, not required)

If conditions 1-4 are met, this table is considered as a many-to-many list.
Foreign key info in SQLite comes from detail/linked table, so it is either N:1 or 1:1

*/
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

    */
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
    /*
     Processes indexes specification using following rules:
     1) primary and unique indexes on single columns are processed as is
     2) unique indexes as well as partial indexes are not supported. Warning will be generated
     TODO: create composite computed properties
     3) DESC clause in index definition is ignored. Warning will be generated.
     4) non-unique indexes on text columns are converted to FTS indexes
     5) all numeric and datetime columns included into non-unique indexes (both single and multi column)
     are considered to participate in RTree index. Maximum 5 columns can be RTree-indexed. Priority is given
     6) Columns from non-unique indexes that were not included into FTS nor RTree indexes will be indexed. Note:
     for multi-column indexes only first columns in index definitions will be processed.
     7) All columns from non-unique indexes that were not included into FTS, RTree or regular indexes will NOT be indexed
     Warning be generated
     */

    /*
     Applies some guessing about role of columns based on their indexing and naming
     The following rules are applied:
     1) primary not autoincrement or unique non-text column gets role "uid"
     2) unique text column(s) get roles "code" and "name".
     3) If unique column name ends with '*Code'
     or its max length is shortest among other unique text columns, it gets role "code"
     4) If unique column name ends with "*Name", it gets role "name",
     */


    /*
     Loads all metadata for the SQLite table (columns, indexes, foreign keys)
     Builds complete ITableInfo and returns promise for it
     */
     ]]
---@param tblDef ISQLiteTableInfo
---@return ITableInfo
function SQLiteSchemaParser:loadTableInfo(tblDef)
    -- Init resulting dictionary
    -- IClassDefinition
    local modelDef = {
        properties = {},
        specialProperties = {}
    }

    self.outSchema[tblDef.name] = modelDef

    -- ITableInfo
    local tableInfo = {
        table = tblDef.name,
        columnCount = 0,
        columns = {},
        inFKeys = {},
        outFKeys = {},
        manyToManyTable = false,
        multiPKey = false
    }
    table.insert(self.tableInfo, tableInfo)

    local tbl_info_st = self.db:prepare(string.format("pragma table_info ('%s');", tblDef.name))
    for col in tbl_info_st:nrows() do
        -- Process columns
        if col.pk > 1 and not tableInfo.multiPKey then
            tableInfo.multiPKey = true

            -- IFlexishResultItem
            local msg = {
                type = 'warn',
                message = 'Multi-column primary key is not supported',
                tableName = tableInfo.table
            }
            table.insert(self.results, msg)
        end

        local prop = self:sqliteColToFlexiProp(col)

        prop.rules.maxOccurences = 1
        prop.rules.minOccurences = tonumber(col.notnull)

        if col.pk == 1 and not tableInfo.multiPKey then
            -- TODO Handle multiple column PKEY
            prop.index = 'unique'
        end

        if col.dflt_value then
            prop.defaultValue = col.dflt_value
        end

        modelDef.properties[col.name] = prop

        tableInfo.columns[col.cid] = col
        tableInfo.columnCount = tableInfo.columnCount + 1
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
        local pkCol = table.find(tableInfo.columns, function(cc)
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

    tableInfo.indexes = indexes;

    tableInfo.supportedIndexes = table.filter(indexes, function(idx)
        return idx.partial == 0 and (string.lower(idx.origin) == 'c' or string.lower(idx.origin) == 'pk');
    end)

    -- Process all supported indexes
    for i, idx in pairs(tableInfo.supportedIndexes) do
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
            table.insert(tableInfo.supportedIndexes[ii].columns, idxCol)
        end
    end

    -- Process foreign keys
    local fkInfo = {}
    for v in self.db:nrows(string.format("pragma foreign_key_list('%s')", tblDef.name)) do
        table.insert(fkInfo, v)
    end

    if #fkInfo > 0 then
        for i, fk in ipairs(fkInfo) do
            fk.srcTable = tableInfo.table
            fk.processed = false
            table.insert(tableInfo.outFKeys, fk)

            local outTbl = self:findTableInfoByName(fk.table)
            if not outTbl then
                table.insert(self.results, {
                    type = 'error',
                    message = "Table specified in FKEY not found",
                    tableName = fk.table
                })
                break
            end

            table.insert(outTbl.inFKeys, fk)
        end
    end

    return tableInfo;
end

---@param tbl ITableInfo
---@param idx ISQLiteIndexInfo
function SQLiteSchemaParser:getIndexColumnNames(tbl, idx)
    local result = {}
    for i, c in ipairs(idx.columns) do
        table.insert(result, tbl.columns[c.cid].name)
    end
    return table.concat(result, ',')
end

---@param tblInfo ITableInfo
function SQLiteSchemaParser:processFlexiliteClassDef(tblInfo)
    local classDef = self.outSchema[tblInfo.table]
    local pkCols = table.filter(tblInfo.columns, function(cc)
        return cc.pk > 0
    end)

    --[[
             Process foreign keys. Defines reference properties.
         There are 3 cases:
         1) normal 1:N, (1 is defined in inFKeys, N - in outFKeys)
         2) extending 1:1, when outFKeys column is primary column
         3) many-to-many M:N, via special table with 2 columns which are foreign keys to other table(s)

         Note: currently Flexilite does not support multi-column primary keys, thus multi-column
         foreign keys are not supported either
    ]]

    local many2many = false
    if tblInfo.columnCount == 2 and #tblInfo.outFKeys == 2
    and #tblInfo.inFKeys == 1 then
        --[[
    Candidate for many-to-many association
    Full condition: both columns are required
    Both columns are in outFKeys
    Primary key is on columns A and B
    There is another non unique index on column B
    ]]
        many2many = table.isEqual(table.map(tblInfo.columns, 'name'), table.map(tblInfo.outFKeys, 'from'))
    end

    if many2many then
        classDef.storage = 'flexi-rel'
        classDef.storageFlexiRel.master = {
            ownProperty = { name = tblInfo.outFKeys[1].from },
            refClass = { name = tblInfo.outFKeys[1].table },
            refProperty = { name = tblInfo.outFKeys[1].to }
        }

        -- TODO ???
        classDef.storageFlexiRel.master = {
            ownProperty = { name = tblInfo.outFKeys[2].from },
            refClass = { name = tblInfo.outFKeys[2].table },
            refProperty = { name = tblInfo.outFKeys[2].to }
        }

        -- No need to process indexing as this class will be used as a virtual table with no data
        return;
    end

    local extCol, extColIdx = table.find(tblInfo.outFKeys, function(fk)
        return pkCols and #pkCols == 1 and pkCols[1].name == fk.from
    end)

    if extCol then
        -- set mixin property
        classDef.properties[pkCols[1].name] = { rules = { type = 'mixin' }, refDef = { classRef = { name = extCol.table } } }
        extCol.processed = true
        table.remove(tblInfo.outFKeys, extColIdx)
    end

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
            local pp = {
                rules = {
                    type = 'reference',
                    minOccurences = cc.rules.minOccurences,
                    maxOccurences = -(bits.lshift(1, 31))
                }
            }
            local propName = fk.table -- FIXME Pluralize
            if classDef.properties[propName] then
                propName = string.format("%s_%s", propName, fk.from)
            end

            pp.refDef = {
                classRef = { name = fk.table }
            }
            classDef.properties[propName] = pp
            -- TODO set on update, on delete
            fk.processed = true
        end
    end

    for i, fk in ipairs(tblInfo.inFKeys) do
        -- 1 : N
        -- TODO
    end

    -- Set indexing
    self:processUniqueNonTextIndexes(tblInfo, classDef)
    self:processUniqueTextIndexes(tblInfo, classDef)
    self:processUniqueMutiColumnIndexes(tblInfo, self)
    self:processNonUniqueIndexes(tblInfo, classDef)
end

---@param tblInfo ITableInfo
---@param classDef IClassDefinition
function SQLiteSchemaParser:processNonUniqueIndexes(tblInfo, classDef)
    local nonUniqueIndexes = table.filter(tblInfo.supportedIndexes, function(idx)
        return idx.unique ~= 1
    end)

    -- Pool of full text columns
    local ftsCols = { 'X1', 'X2', 'X3', 'X4' }

    -- Pool of rtree columns
    local rtCols = { 'A', 'B', 'C', 'D', 'E' }

    for i, idx in ipairs(nonUniqueIndexes) do
        local col = tblInfo.columns[idx.columns[1].cid]
        local prop = classDef.properties[col.name]

        if prop.rules.type == 'text' then
            if not prop.index then
                if #ftsCols == 0 then
                    prop.index = 'index'
                else
                    local ftsCol = table.remove(ftsCols)
                    classDef.fullTextIndexing = classDef.fullTextIndexing or {}
                    classDef.fullTextIndexing[ftsCol] = { name = col.name }
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
                    classDef.rangeIndexing[rtCol .. '0'] = { name = col.name, }
                    classDef.rangeIndexing[rtCol .. '1'] = { name = col.name }
                    prop.index = 'range'
                end
            end
        else
            prop.index = 'index'
        end
    end
end

---@param tblInfo ITableInfo
function SQLiteSchemaParser:processUniqueMutiColumnIndexes(tblInfo)
    local uniqMultiIndexes = table.filter(tblInfo.supportedIndexes, function(idx)
        return #idx.columns > 1 and idx.unique == 1
    end)

    for i, idx in ipairs(uniqMultiIndexes) do
        -- Unique multi column indexes are not supported
        -- TODO add support
        local msg = string.format(
        "Index [%s] by %s is ignored as multi-column unique indexes are not supported by Flexilite",
        idx.name, self:getIndexColumnNames(tblInfo, idx))

        table.insert(self.results, {
            type = 'warn',
            message = msg,
            tableName = tblInfo.table })
    end
end

---@param tblInfo ITableInfo
---@param classDef IClassDefinition
function SQLiteSchemaParser:processUniqueNonTextIndexes(tblInfo, classDef)
    local uniqOtherIndexes = table.filter(tblInfo.supportedIndexes, function(idx)
        local tt = classDef.properties[tblInfo.columns[idx.columns[1].cid].name].rules.type
        return #idx.columns == 1 and idx.unique == 1 and (tt == 'integer' or tt == 'number' or tt == 'datetime'
        or tt == 'binary')
    end)

    table.sort(uniqOtherIndexes,
    function(A, B)
        if not A or not B then
            return 0
        end

        local function getTypeWeight(item)
            local result = classDef.properties[tblInfo.columns[item.columns[1].cid].name].rules.type
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
        if v1 == v2 then
            return 0
        end
        if v1 > v2 then
            return 1
        end
        return -1
    end )

    if #uniqOtherIndexes > 0 then
        classDef.specialProperties.uid = { name = tblInfo.columns[uniqOtherIndexes[1].columns[1].cid].name }
        for i, idx in ipairs(uniqOtherIndexes) do
            local col = tblInfo.columns[idx.columns[1].cid]
            local prop = classDef.properties[col.name]
            if prop.rules.type == 'binary' and prop.rules.maxLength == 16 then
                classDef.specialProperties.autoUuid = { name = tblInfo.columns[idx.columns[1].cid].name }
            end
        end
    end
end

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
    end)
    table.sort(uniqTxtIndexes, function(A, B)
        if not A or not B then
            return 0
        end

        local v1 = classDef.properties[tblInfo.columns[A.columns[1].cid].name].rules.maxLength
        local v2 = classDef.properties[tblInfo.columns[B.columns[1].cid].name].rules.maxLength
        if v1 == v2 then
            return 0
        end
        if v1 < v2 then
            return -1
        end
        return 1
    end)

    if #uniqTxtIndexes > 0 then
        -- Items assigned to code, name, description
        classDef.specialProperties.code = { name = tblInfo.columns[uniqTxtIndexes[1].columns[1].cid].name }
        if not classDef.specialProperties.uid then
            classDef.specialProperties.uid = classDef.specialProperties.code
        end

        classDef.specialProperties.name = { name = tblInfo.columns[uniqTxtIndexes[#uniqTxtIndexes > 1 and 2 or 1].columns[1].cid].name };
        classDef.specialProperties.description = { name = tblInfo.columns[uniqTxtIndexes[#uniqTxtIndexes].columns[1].cid].name };
    end
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
        local tblInfo = self:loadTableInfo(item)
        self:processFlexiliteClassDef(tblInfo)
    end

    return self.outSchema
end

return SQLiteSchemaParser