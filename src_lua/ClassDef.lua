---
--- Created by slanska.
--- DateTime: 2017-10-31 3:10 PM
---

--[[
Flexilite class (AKA "table") definition
Has reference to DBContext
Corresponds to [.classes] database table plus 'D' property - decoded [data] field,
with initialized PropertyRef's and NameRef's

Find property
Validates class structure
Loads class def from DB
Validates existing data with new class definition
]]

local json = cjson or require 'cjson'
local schema = require 'schema'
local bit52 = require('Util').bit52
local Constants = require 'Constants'
local PropertyDef = require('PropertyDef')
local name_ref = require('NameRef')
local NameRef = name_ref.NameRef
local class = require 'pl.class'
local tablex = require 'pl.tablex'
local AccessControl = require 'AccessControl'
local DictCI = require('Util').DictCI
local List = require 'pl.List'

local table_insert = table.insert
local table_remove = table.remove
local table_concat = table.concat

--[[
Index definitions for class. Operate with property IDs only,
so properties of new class must be saved prior to using this class.
Used for:
a) organizing indexes, e.g. eliminating duplicates in index definition
b) finding best index
c) applying changes for index storage
d) storing and loading index definitions (in [.classes].Data.indexes)
]]

---@class IndexDefinitions
---@field fullTextIndexing number[]  @comment array of property IDs
---@field rangeIndexing number[]  @comment array of property IDs
---@field multiKeyIndexing number[]  @comment Array of 0, 2, 3 or 4 property IDs
---@field propIndexing table<number, boolean>  @comment map of property IDs to boolean (unique or not)
local IndexDefinitions = class()

-- Internal static variables for column names
IndexDefinitions.ftsCols = { 'X1', 'X2', 'X3', 'X4', 'X5' }
IndexDefinitions.rngCols = { 'A0', 'A1', 'B0', 'B1', 'C0', 'C1', 'D0', 'D1', 'E0', 'E1' }

-- Initializes empty index definition
function IndexDefinitions:_init()
    -- Full text index. Array 1..5 to property ID (1 = X1, 2 = X2 ...)
    self.fullTextIndexing = {}

    -- Range index. Array 1 .. 10 to property ID (1 = A0, 2 = A1, 3 = B0...)
    self.rangeIndexing = {}

    -- Multi property unique indexes. Array of 2, 3 or 4 items (property IDs)
    self.multiKeyIndexing = {  }

    -- Indexes for single properties. Map by property ID to boolean
    -- (false - non-unique index, true - unique index)
    self.propIndexing = {}
end

-- Converts array of property IDs to dictionary of number and index
---@param arr number[]
---@return table<number, number> @comment key - property ID, value - index in arr
function IndexDefinitions:IndexArrayToMap(arr)
    local result = {}
    for i, v in ipairs(arr) do
        result[v] = i
    end
    return result
end

-- Converts full text index definition from array to dictionary
function IndexDefinitions:FullTextIndexAsMap()
    return self:IndexArrayToMap(self.fullTextIndexing)
end

---@param propDef PropertyDef
---@return boolean, string @comment true if ok, false and error message if failed
function IndexDefinitions:AddFullTextIndexedProperty(propDef)
    assert(propDef and propDef.ID)

    local supportedIndexTypes = propDef:GetSupportedIndexTypes()
    if bit52.band(supportedIndexTypes, Constants.INDEX_TYPES.FTS) ~= Constants.INDEX_TYPES.FTS then
        return false, string.format('Property %s does not support full text indexing',
                propDef:debugDesc())
    end

    -- Already set?
    local existingIndex = tablex.find(self.fullTextIndexing, propDef.ID)
    if existingIndex then
        return true, nil
    end

    if #self.fullTextIndexing == 5 then
        return false, 'Maximum number of properties in full text index (5) exceeded'
    end
    table_insert(self.fullTextIndexing, propDef.ID)
    return true, nil
end

---@param propDef0 PropertyDef @comment Low bound property definition
---@param propDef1 PropertyDef @comment High bound property definition
---@return boolean, string @comment true and info message if ok, false and error message if failed
function IndexDefinitions:AddRangeIndexedProperties(propDef0, propDef1)
    assert(propDef0 and propDef0.ID)

    propDef1 = propDef1 or propDef0

    for _, propDef in ipairs({ propDef0, propDef1 }) do
        local supportedIndexTypes = propDef:GetSupportedIndexTypes()
        if bit52.band(supportedIndexTypes, Constants.INDEX_TYPES.RNG) ~= Constants.INDEX_TYPES.RNG then
            return false, string.format('Property %s does not support range indexing',
                    propDef:debugDesc())
        end
    end

    local idx0 = tablex.find(self.rangeIndexing, propDef0.ID)
    local idx1 = tablex.find(self.rangeIndexing, propDef1.ID)
    if idx0 and idx1 == (idx0 + 1) then
        return true, 'Properties  already in range index'
    end

    if idx0 or idx1 then
        return false, 'Existing range index specification conflict'
    end

    if #self.rangeIndexing == 10 then
        return false, 'Maximum number of dimensions in range index (5) exceeded'
    end

    table_insert(self.rangeIndexing, propDef0.ID)
    table_insert(self.rangeIndexing, propDef1.ID)
    return true, nil
end

---@param propDefs PropertyDef[]
---@return boolean, string @comment true if ok, false and error message if failed
function IndexDefinitions:AddMultiKeyIndex(propDefs)
    assert(propDefs)
    local len = #propDefs
    if len < 2 or len > 4 then
        return false, string.format(
                'Invalid number of properties in multi key specification - %d. Must be between 2 and 4',
                len)
    end

    for _, propDef in ipairs(propDefs) do
        local supportedIndexTypes = propDef:GetSupportedIndexTypes()
        if bit52.band(supportedIndexTypes, Constants.INDEX_TYPES.MUL) ~= Constants.INDEX_TYPES.MUL then
            return false, string.format('Property %s does not support multi key indexing',
                    propDef:debugDesc())
        end

        -- Check for accidental duplicates
        local all = tablex.imap(function(p)
            return p.ID == propDef.ID
        end, propDefs)

        if #all > 1 then
            return false, string.format('Property %s is repeated more than once in multi key index',
                    propDef:debugDesc())
        end
    end

    self.multiKeyIndexing = tablex.imap(function(propDef)
        return propDef.ID
    end, propDefs)

    return true, nil
end

-- Adds/updates index definition for a given property
---@param propDef PropertyDef
---@param unique boolean
---@return boolean, string @comment true if ok, false and error message if failed
function IndexDefinitions:AddIndexedProperty(propDef, unique)
    assert(propDef and propDef.ID)

    local supportedIndexTypes = propDef:GetSupportedIndexTypes()
    local expectedIndexType = unique and Constants.INDEX_TYPES.UNQ or Constants.INDEX_TYPES.STD
    if bit52.band(supportedIndexTypes, expectedIndexType) ~= expectedIndexType then
        return false, string.format('Property %s does not support indexing',
                propDef:debugDesc())
    end

    if not unique then
        -- Find possible usage of the same property in other types of indexes
        local idx = tablex.find(self.rangeIndexing, propDef.ID)
        if idx then
            table_remove(self.propIndexing, propDef.ID)
            return true, string.format('Property %s already included in range index',
                    propDef:debugDesc())
        end

        if self.multiKeyIndexing and #self.multiKeyIndexing > 0
                and self.multiKeyIndexing[1] == propDef.ID then
            table_remove(self.propIndexing, propDef.ID)
            return true, string.format('Property %s already included in multi key index',
                    propDef:debugDesc())
        end
    end

    self.propIndexing[propDef.ID] = unique
    return true, nil
end

function IndexDefinitions:__eq(A, B)
    return tablex.deepcompare(A, B)
end

-- Processes indexing for individual property
---@param propDef PropertyDef
---@return boolean, string @comment true if ok, false and error message if failed
function IndexDefinitions:SetPropertyIndex(propDef)
    assert(propDef and propDef.ID)

    local idxType = string.lower(propDef.D.index or '')
    if idxType == '' then
        if self.propIndexing[propDef.ID] then
            table_remove(self.propIndexing, propDef.ID)
            return true, string.format('Index for property [%s] was removed', propDef.Name.text)
        end
        return true, nil
    elseif idxType == 'fulltext' then
        return self:AddFullTextIndexedProperty(propDef)
    elseif idxType == 'range' then
        if tablex.find(self.rangeIndexing, propDef.ID) then
            return true, nil
        end
        return self:AddRangeIndexedProperties(propDef, nil)
    elseif idxType == 'unique' then
        return self:AddIndexedProperty(propDef, true)
    elseif idxType == 'index' then
        return self:AddIndexedProperty(propDef, false)
    end

    return false, 'Unknown index'
end

function IndexDefinitions:toInternalJSON()
    local result = {}
    -- TODO
    return result
end

---@class propColMap
---@field A NameRef
---@field B NameRef
---@field C NameRef
---@field D NameRef
---@field E NameRef
---@field F NameRef
---@field G NameRef
---@field H NameRef
---@field I NameRef
---@field J NameRef
---@field K NameRef
---@field L NameRef
---@field M NameRef
---@field N NameRef
---@field O NameRef
---@field P NameRef

---@class specialProperties
---@field uid NameRef

---@class ClassDefIndexes
---@field fullTextIndexing  NameRef[] @comment array of property ref
---@field rangeIndexing  NameRef[] @comment array of property ref (even number: 2, 4, 6, 8, 10)
---@field multiKeyIndexing  NameRef[] @comment Array of 0, 2, 3 or 4 property ref

---@class ClassDefData
---@field properties table<string, PropertyDefData>
---@field indexes ClassDefIndexes
---@field specialProperties specialProperties
---@field meta any @comment Custom schema for meta data (defined by user on database level)
---@field accessRules table @comment TODO define structure of access rules

---@class ClassDef
---@field ClassID number
---@field DBContext DBContext
---@field Properties table <string, PropertyDef>
---@field MixinProperties table
---@field propColMap propColMap
---@field CheckedInTrn number
---@field objectSchema table @comment 2 keys - 'C' and 'U', for created and updated objects
---@field indexes IndexDefinitions
---@field Name NameRef
---@field D ClassDefData @comment parsed Data column
---@field SystemClass boolean
---@field VirtualTable boolean
---@field Deleted boolean
---@field ColMapActive boolean
---@field vtypes number
local ClassDef = class()

---@class ClassDefCtorParamsData
---@field NameID number

---@class ClassDefCtorParams
---@field DBContext DBContext
---@field newClassName string
---@field data ClassDefCtorParamsData | string @comment .classes row or encoded JSON

--- ClassDef constructor
---@param params ClassDefCtorParams
function ClassDef:_init(params)
    self.DBContext = params.DBContext

    --[[ Properties by name
    Lookup by property name. Includes class own properties
    ]]
    self.Properties = DictCI()
    -- TODO self.Properties = {}

    -- Properties from mixin classes, by name
    -- Values are lists of PropertyDef - [propName][i]
    self.MixinProperties = {}

    -- set column mapping dictionary, value is either nil or PropertyDef
    self.propColMap = { }

    self.CheckedInTrn = 0

    -- Object schema (for create and update operations)
    self.objectSchema = {}

    local data

    if params.newClassName then
        -- New class initialization. params.data is either string or JSON
        -- and it is JSON with class definition
        self.indexes = IndexDefinitions()

        data = params.data
        if type(data) == 'string' then
            data = json.decode(data)
        end

        -- Class name reference
        self.Name = NameRef(params.newClassName)
        self.D = {}

        for propName, propJsonData in pairs(data.properties) do
            self:AddNewProperty(propName, propJsonData)
        end
    else
        -- Loading existing class from DB. params.data is [.classes] row
        assert(type(params.data) == 'table')
        self.Name = NameRef(params.data.Name, params.data.NameID)
        self.ClassID = params.data.ClassID
        self.ctloMask = params.data.ctloMask
        self.SystemClass = params.data.SystemClass
        self.VirtualTable = params.data.VirtualTable
        self.Deleted = params.data.Deleted
        self.ColMapActive = params.data.ColMapActive
        self.vtypes = params.data.vtypes

        assert(type(params.data.Data) == 'string', string.format('%s: params.data.Data must be valid JSON. Got %s',
                params.data.Name, type(params.data.Data)))
        self.D = json.decode(params.data.Data)
        data = self.D

        -- Load from .class_props
        for propRow in self.DBContext:loadRows([[
        select PropertyID, ClassID, NameID, Property, ctlv, ctlvPlan,
            Deleted, SearchHitCount, NonNullCount from [flexi_prop] cp where cp.ClassID = :ClassID;]],
                { ClassID = self.ClassID }) do
            self:loadPropertyFromDB(propRow, assert(self.D.properties[tostring(propRow.PropertyID)], 'Null property definition'))
        end

        -- Initialize indexes
        self.indexes = tablex.deepcopy(self.D.indexes) or {}
        setmetatable(self.indexes, IndexDefinitions)
    end

    ---@param dictName string
    local function dictFromJSON(dictName)
        self.D[dictName] = {}
        local tt = data[dictName]
        if tt then
            for k, v in pairs(tt) do
                self.D[dictName][k] = v
                self.DBContext:InitMetadataRef(self.D[dictName], k, NameRef)
            end
        end
    end

    dictFromJSON('specialProperties')
    dictFromJSON('rangeIndexing')
    dictFromJSON('fullTextIndexing')

    self:initMixinProperties()
end

-- Initializes existing property loaded from database. Internally used method
---@param dbrow table @comment flexi_prop view structure
---@param propJsonData table @comment property definition according to schema
function ClassDef:loadPropertyFromDB(dbrow, propJsonData)
    local prop = PropertyDef.CreateInstance { ClassDef = self, dbrow = dbrow, jsonData = propJsonData }
    self.Properties[dbrow.Property] = prop
end

-- Internal method to add property definition to the property list
-- Called when a) creating a new class, b) loading existing class from DB,
-- c) altering existing class
---@param propName string
---@param propJsonData PropertyDefData
---@return PropertyDef
function ClassDef:AddNewProperty(propName, propJsonData)
    local prop = PropertyDef.CreateInstance { ClassDef = self, newPropertyName = propName, jsonData = propJsonData }
    self.Properties[propName] = prop

    return prop
end

-- Fills MixinProperties with properties from mixin classes, if applicable
function ClassDef:initMixinProperties()
    self.MixinProperties = {}
    for _, pp in pairs(self.Properties) do
        --if pp:is_a(PropertyDef.PropertyTypes['mixin']) then
        --    assert(pp.refDef and pp.refDef.classRef)
        --    local mixin = self.DBContext:getClassDef(pp.refDef.classRef.ID)
        --
        --    for _, mp in pairs(mixin.Properties) do
        --        local d = self.MixinProperties[mp.Name.text]
        --        if not d then
        --            d = {}
        --            self.MixinProperties[mp.Name.text] = d
        --        end
        --        table_insert(d, mp)
        --    end
        --end
    end
end

-- Attempts to assign column mapping
---@param prop PropertyDef
---@return boolean
function ClassDef:assignColMappingForProperty(prop)
    -- Already assigned?
    if prop.ColMap then
        return true
    end

    -- Not all properties support column mapping. Check it
    if not prop:ColumnMappingSupported() then
        return false
    end

    -- Find available slot
    local cols = 'ABCDEFGHIJKLMNOP'
    for ch in cols:gmatch '.' do
        if not self.propColMap[ch] then
            -- Available slot!
            self.propColMap[ch] = prop
            prop.ColMap = ch
            return true
        end
    end

    return false
end

---@param propName string
---@return PropertyDef | nil
function ClassDef:hasProperty(propName)
    local result = self.Properties[propName]
    if result then
        return result
    end
    local mixins = self.MixinProperties[propName]
    if not mixins or #mixins ~= 1 then
        return nil
    end
    return mixins[1]
end

---@param propName string
---@return PropertyDef @comment throws error if property is not found
function ClassDef:getProperty(propName)
    -- Check if exists

    local prop = self:hasProperty(propName)
    if not prop then
        error(string.format("Property `%s` not found or ambiguous in class `%s`", propName, self.Name.text))
    end
    return prop
end

---@return table @comment User friendly encoded JSON of class definition (excluding raw and internal properties)
function ClassDef:toJSON()
    local result = {
        id = self.ID,
        text = self.Name,
        allowAnyProps = self.allowAnyProps,
    }

    ---@return nil
    local function dictToJSON(dictName)
        local dict = self[dictName]
        if dict then
            result[dictName] = {}
            for ch, n in pairs(dict) do
                assert(n)
                result[dictName][ch] = n.toJSON()
            end
        end
    end

    for _, p in ipairs(self.Properties) do
        result[p.Name] = p.toJSON()
    end

    dictToJSON('specialProperties')
    dictToJSON('fullTextIndexing')
    dictToJSON('rangeIndexing')

    return result
end

--- Returns internal representation of class definition, as it is stored in [.classes] db table
---Properties are indexed by property IDs
---@return ClassDefData
function ClassDef:internalToJSON()
    ---@type ClassDefData
    local result = { properties = {} }

    for _, prop in pairs(self.Properties) do
        result.properties[tostring(prop.ID)] = prop:internalToJSON()
    end

    -- TODO Other attributes?
    result.specialProperties = tablex.deepcopy(self.D.specialProperties)

    result.indexes = tablex.deepcopy(self.indexes)

    return result
end

-- Creates range data table for the given class
function ClassDef:createRangeDataTable()
    assert(type(self.ClassID) == 'number')
    local sql = string.format([[
    CREATE VIRTUAL TABLE IF NOT EXISTS [.range_data_%d] USING rtree (
          [ObjectID],
          [A0], [A1],
          [B0], [B1],
          [C0], [C1],
          [D0], [D1],
          [E0], [E1]
        );]], self.ClassID)
    self.DBContext:ExecAdhocSql(sql)
end

function ClassDef:dropRangeDataTable()
    assert(type(self.ClassID) == 'number')
    local sql = string.format([[DROP TABLE IF EXISTS [.range_data_%d];]], self.ClassID)
    local result = self.DBContext.db:exec(sql)
    if result ~= 0 then
        local errMsg = string.format("%d: %s", self.DBContext.db:error_code(), self.DBContext.db:error_message())
        error(errMsg)
    end
end

-- Updates class definition in database. Is is expected to be already created
-- (INSERT INTO already run and class ID is known)
-- Properties are expected to be saved to DB and have IDs assigned
function ClassDef:saveToDB()
    assert(self.ClassID > 0)

    local internalJson = ''

    local internal = self:internalToJSON()
    local sparse = json.encode_sparse_array()
    json.encode_sparse_array(true)
    internalJson = json.encode(internal)
    json.encode_sparse_array(sparse)

    -- Calculate ctloMask and vtypes
    self.vtypes = 0
    self.ctloMask = 0
    for _, propDef in pairs(self.propColMap) do
        assert(propDef)
        local colIdx = propDef:ColMapIndex()
        local vtmask = bit52.bnot(bit52.lshift(7, colIdx * 3))
        local vtype = bit52.lshift(propDef:GetVType(), colIdx * 3)

        self.vtypes = bit52.set(self.vtypes, vtmask, vtype)

        if propDef.index == 'unique' then
            local idxMask = bit52.bnot(bit52.lshift(1, colIdx + Constants.CTLO_FLAGS.UNIQUE_SHIFT))
            self.ctloMask = bit52.set(self.ctloMask, idxMask, 1)
        elseif propDef.index == 'index' then
            -- TODO Check if property should be indexed
            local idxMask = bit52.bnot(bit52.lshift(1, colIdx + Constants.CTLO_FLAGS.INDEX_SHIFT))
            self.ctloMask = bit52.set(self.ctloMask, idxMask, 1)
        end
    end

    self.DBContext:execStatement([[update [.classes] set NameID = :NameID, Data = :Data,
        ctloMask = :ctloMask, vtypes = :vtypes where ClassID = :ClassID;]],
            {
                NameID = self.Name.id,
                Data = internalJson,
                ctloMask = self.ctloMask,
                vtypes = self.vtypes,
                ClassID = self.ClassID
            })
end

-- Converts "free" index definition to a normalized format.
-- Indexes may be defined on individual properties level as well as on class level ('indexes' )
-- Class and its properties must be already saved, i.e. must have IDs assigned
-- During normalization, also validates index definitions
-- Used to optimize index definitions and also to prepare differences in indexes for AlTER CLASS/ALTER
---@return IndexDefinitions
function ClassDef:normalizeIndexDefinitions()
    local result = IndexDefinitions()

    if self.D.indexes then
        for _, indexDef in pairs(self.D.indexes) do
            local indexType = string.lower(indexDef.type or 'index')
            local props = indexDef.properties
            if type(props) == 'string' then
                props = { name_ref.PropertyRef(nil, props) }
                props[1]:resolve(self)
            else
                if type(props) ~= 'table' then
                    props = { props }
                end
                props = tablex.map(function(pp)
                    local ref = name_ref. PropertyRef(pp.id, pp.text)
                    ref:resolve(self)
                    return ref
                end, props)
            end

            if indexType == 'range' then
                -- Up to 10 values to be indexed by RTREE. Properties are processed in pairs
                local propDefs = tablex.imap(function(pp)
                    return self:getProperty(pp.text)
                end, props)

                for ii = 1, #propDefs, 2 do
                    local ok, msg = result:AddRangeIndexedProperties(propDefs[ii], propDefs[ii + 1])
                    if not ok then
                        error(msg)
                    end
                end

            elseif indexType == 'unique' then
                -- if 2..4 properties are listed, this is multi key index
                -- if 1 property, this is regular unique index
                if #props >= 2 and #props <= 4 then
                    local propDefs = tablex.map(function(propRef)
                        return self:getProperty(propRef.text)
                    end, props)
                    local ok, msg = result:AddMultiKeyIndex(propDefs)
                    if not ok then
                        error(msg)
                    end
                elseif #props ~= 1 then
                    error(string.format('Invalid number of keys in unique/multi key index'))
                else
                    local propDef = self:getProperty(props[1].text)
                    local ok, msg = result:AddIndexedProperty(propDef, true)
                    if not ok then
                        error(msg)
                    end
                end
            elseif indexType == 'fulltext' then
                for _, propRef in ipairs(props) do
                    local propDef = self:getProperty(propRef.text)
                    local ok, msg = result:AddFullTextIndexedProperty(propDef)
                    if not ok then
                        error(msg)
                    end
                end
            elseif indexType == 'index' then
                -- if 2..5 properties in the list, there is attempt to apply range index
                -- otherwise, apply individual indexing
                if #indexDef >= 2 and #indexDef <= 5 then

                end
            end
        end
    end

    for _, propDef in pairs(self.Properties) do
        local ok, msg = self.indexes:SetPropertyIndex(propDef)
        if not ok then
            error(msg)
        end
    end

    return result
end

-- Static (class level) method
---@param propDef PropertyDef
---@return number @comment integer mask for indexed propDef.ColMap property
function ClassDef.getCtloMaskForColMapIndex(propDef)
    local result = 0
    local colIdx = string.byte(propDef.ColMap) - string.byte('A')
    if propDef.index == 'unique' then
        result = bit52.lshift(1, colIdx + Constants.CTLO_FLAGS.UNIQUE_SHIFT)
    elseif propDef.index == 'index' then
        result = bit52.lshift(1, colIdx + Constants.CTLO_FLAGS.INDEX_SHIFT)
    end
    return result
end

-- Static (class level) method
-- Applies changes in class' index definitions
-- Potentially long operation to update indexes (drop, create, update etc.)
---@param oldClassDef ClassDef
---@param newClassDef ClassDef
function ClassDef.ApplyIndexing(oldClassDef, newClassDef)
    assert(newClassDef and (oldClassDef == nil or oldClassDef ~= newClassDef))

    local oldIdxDef = oldClassDef and oldClassDef:normalizeIndexDefinitions() or IndexDefinitions()

    local newIdxDef = newClassDef:normalizeIndexDefinitions()

    local emptyDummy = {}

    -- Changed and added indexes
    local propIdxDiff = tablex.difference(oldIdxDef.propIndexing or emptyDummy, newIdxDef.propIndexing or emptyDummy)

    -- Properties that were indexed in old definition, but not indexed anymore
    local propIdxDeleted = tablex.difference(newIdxDef.propIndexing or emptyDummy, oldIdxDef.propIndexing or emptyDummy)

    -- All changed properties: added, changed and deleted
    local changedPropIdx = tablex.merge(propIdxDeleted, propIdxDiff)

    -- Update ctlv and ctlo flags
    for _, propDef in pairs(newClassDef.Properties) do
        if propIdxDeleted[propDef.ID] then
            propDef.index = nil
        end

        if propDef.ColMap then
            local mask = ClassDef.getCtloMaskForColMapIndex(propDef)

            -- TODO set ctlo
        end

        propDef:beforeSaveToDB()
        propDef:saveToDB()
    end

    -- Drop .range_data
    if not tablex.deepcompare(oldIdxDef.rangeIndexing or emptyDummy, newIdxDef.rangeIndexing or emptyDummy) then
        -- Create .range_data
        newClassDef:dropRangeDataTable()
        newClassDef:createRangeDataTable()

        --[[insert ]]
        local sqlLines = { string.format('insert into [.range_data_%d] (ObjectID', newClassDef.ClassID),
                           ') select Object' }
        local colNameIdx = 1
        local colValIdx = 2

        for idx, propID in ipairs(newIdxDef.rangeIndexing or emptyDummy) do
            local propDef = newClassDef.DBContext.ClassProps[propID]
            colNameIdx = colNameIdx + 1
            colValIdx = colValIdx + 2
            table_insert(sqlLines, colNameIdx, string.format(', %s', IndexDefinitions.rngCols[idx]))
            table_insert(sqlLines, colValIdx, propDef:GetColumnExpression(false))
        end

        table_insert(sqlLines, ' from [.objects] where ClassID = :ClassID);')
        local sql = table_concat(sqlLines)
        newClassDef.DBContext:ExecAdhocSql(sql, { ClassID = newClassDef.ClassID })
    end

    -- Update .ref_values with new ctlv flags

    -- Update .objects with new ctlo flags

    -- Full text indexing
    if not tablex.deepcompare(oldIdxDef.fullTextIndexing or emptyDummy, newIdxDef.fullTextIndexing or emptyDummy) then
        -- Delete from .full_text_data
        newClassDef.DBContext:ExecAdhocSql([[delete from [.full_text_data] where ClassID = :ClassID;]], { ClassID = oldClassDef.ClassID })

        -- Insert into .full_text_data

        local colNamePos = 1
        local colValPos = 2
        local sqlLines = { 'insert into [.full_text_data] (id, ClassID',
                           string.format(') select ObjectID, %d ', newClassDef.ClassID),
        }
        for ii, propID in ipairs(newIdxDef.fullTextIndexing) do
            local propDef = newClassDef.DBContext.ClassProps[propID]
            colNamePos = colNamePos + 1
            colValPos = colValPos + 2
            table_insert(sqlLines, colNamePos, string.format(', [X%d]', ii))
            table_insert(sqlLines, colValPos, propDef:GetColumnExpression(false))
        end
        table_insert(sqlLines, ' from [.objects] where ClassID = :ClassID);')
        local sql = table_concat(sqlLines, '')
        newClassDef.DBContext:ExecAdhocSql(sql, { ClassID = newClassDef.ClassID })
    end

    -- multi_key indexing
    if not tablex.deepcompare(newIdxDef.multiKeyIndexing, oldIdxDef.multiKeyIndexing) then
        -- Delete from .multi_key_N
        if #oldIdxDef.multiKeyIndexing > 0 then
            oldClassDef.DBContext:ExecAdhocSql(string.format('delete from [.multi_key%d] where ClassID = :ClassID',
                    #oldIdxDef.multiKeyIndexing),
                    { ClassID = oldClassDef.ClassID })
        end

        -- Insert into .multi_key_N
        local colNameIdx = 1
        local colValIdx = 2
        local sqlLines = { string.format('insert into [.multi_key%d] (ClassID',
                #newIdxDef.multiKeyIndexing, newClassDef.ClassID),
                           ') select (:ClassID' }
        for iCol, propID in ipairs(newIdxDef.multiKeyIndexing[#newIdxDef.multiKeyIndexing]) do
            local propDef = newClassDef.DBContext.ClassProps[propID]
            colNameIdx = colNameIdx + 1
            colValIdx = colValIdx + 2
            table_insert(sqlLines, colNameIdx, string.format(', [Z%d]', iCol))
            table_insert(sqlLines, colValIdx, propDef:GetColumnExpression(false))
        end
        table_insert(sqlLines, ' from [.objects] where ClassID = :ClassID);')
        local sql = table_concat(sqlLines)
        newClassDef.DBContext:ExecAdhocSql(sql, { ClassID = newClassDef.ClassID })
    end
end

-- Generates schema for object validation. Sets self.objectSchema field
---@param op string @comment 'C' for create new object, 'U' for update existing object
function ClassDef:getObjectSchema(op)
    assert(op == 'C' or op == 'U')

    local result = self.objectSchema[op]
    if result then
        return result
    end

    local objSchema = {}

    -- own properties
    for propName, propDef in pairs(self.Properties) do
        local propSchema = propDef:GetValueSchema(op)
        if op == 'U' then
            propSchema = schema.Optional(propSchema)
        end
        objSchema[propName] = propSchema
    end

    -- mixin properties which do not duplicate own properties
    -- they can be accessed as own properties
    for _, propDefs in pairs(self.MixinProperties) do
        if not objSchema[name] and #propDefs == 1 then
            local propSchema = propDefs[1]:GetValueSchema(op)
            local name = string.lower(propDefs[1].Name.text)
            if op == 'U' then
                propSchema = schema.Optional(propSchema)
            end
            objSchema[name] = propSchema
        end
    end

    result = schema.Record(objSchema, self.allowAnyProps)
    self.objectSchema[op] = result
    return result
end

---@param propKey string
---@return PropertyDef | nil @comment Special property if applicable
function ClassDef:getSpecialProperty(propKey)
    if self.D.specialProperties ~= nil then
        local pp = self.D.specialProperties[propKey]
        if pp ~= nil then
            local result = self:getProperty(pp.text)
            return result
        end
    end

    return nil
end

---@return PropertyDef | nil @comment User Defined ID property, if applicable
function ClassDef:getUdidProp()
    return self:getSpecialProperty('uid')
end

---@param propDef PropertyDef
---@param v any
---@param fetchLimit number | nil
---@return DBObject[]
function ClassDef:lookupObjectsByProperty(propDef, v, fetchLimit)
    assert(propDef)
    local indexMask = propDef:getIndexMask()
    if self.ColMapActive and propDef.ColMap then
        -- Query .objects
        local sql = ('select ObjectID from [.objects] where ClassID = :classID and %s = :colMap and (ctlo & :ctloMask) = :ctloMask')
                :format(propDef.ColMap)
        local row = self.DBContext:loadOneRow(sql, { classID = propDef.ClassDef.ID, colMap = propDef.ColMap, ctloMask = indexMask })
        if not row then
            return {}
        end

        local objectId = row[propDef.ColMap]
        local obj = self.DBContext:getObject(objectId)
        return { obj }
    else
        -- Query .ref-values
        local sql = List()
        sql:append 'select ObjectID from [.ref-values] where PropertyID = :propID'
        if indexMask == 8 then
            -- Unique index
            sql:append ' and (ctlv & 8) '
        elseif indexMask ~= 0 then
            -- Non-Unique index or reference
            sql:append ' and (ctlv & 0xF0)'
        end
        if fetchLimit then
            sql:append ' limit '
            sql:append(tostring(fetchLimit))
        end
        sql:append ';'

        local result = {}
        for rr in self.DBContext:loadRows(sql:join(''), { propID = propDef.ID }) do
            local obj = self.DBContext:getObject(rr.ObjectID)
            table_insert(result, obj)
        end
        return result
    end
end

---@param udidValue string | number
---@param mustExist boolean | nil
---@return DBObject
function ClassDef:getObjectByUdid(udidValue, mustExist)
    local udidPropDef = self:getUdidProp()
    if udidPropDef == nil then
        error(string.format('UDID property is not defined for class [%s]', self.Name.text))
    end

    local foundObjects = self:lookupObjectsByProperty(udidPropDef, udidValue, 1)
    if #foundObjects == 0 and mustExist then
        error(string.format('Object with UDID %s not found in class [%s]', tostring(udidValue), self.Name.text))
    end

    return foundObjects[1]
end

-- define schema for class JSON definition
ClassDef.Schema = schema.Record {
    properties = schema.Map(name_ref.IdentifierSchema, PropertyDef.Schema),
    ui = schema.Any, -- TODO finalize
    allowAnyProps = schema.Optional(schema.Boolean),
    specialProperties = schema.Optional(schema.Record {
        -- User defined ID. Unique and required
        uid = schema.Optional(NameRef.Schema),

        -- Object name (required and mostly unique)
        name = schema.Optional(NameRef.Schema),

        -- Object description
        description = schema.Optional(NameRef.Schema),

        -- Another alternative ID. Unlike ID, can be changed
        code = schema.Optional(NameRef.Schema),

        --Alternative ID that allows duplicates
        nonUniqueId = schema.Optional(NameRef.Schema),

        -- Timestamp on when object was created
        createTime = schema.Optional(NameRef.Schema),

        -- Timestamp on when object was last updated
        updateTime = schema.Optional(NameRef.Schema),

        -- Auto generated UUID (16 byte blob)
        -- TODO add schema.Case to check type of autoUuid property
        autoUuid = schema.Optional(NameRef.Schema),

        -- Auto generated short ID (7-16 characters)
        autoShortId = schema.Optional(NameRef.Schema),

        -- Object owner
        owner = schema.Optional(NameRef.Schema),
    }),

    --[[
        This is the only way to define multi-column unique indexes
        'range' and 'fulltext' indexes are merged and resulting number of columns must not
        exceed limits (5 full text columns and 5 dimensions for range index)
        'range' indexes must be defined in pairs (even number of properties, i.e. 2, 4, 6, 8 or 10)
        keys in this tables (aka 'index name') are ignored
        ]]
    indexes = schema.Optional(schema.Record {
        rangeIndexing = schema.Optional(schema.Collection(NameRef.Schema)),
        fullTextIndexing = schema.Optional(schema.Collection(NameRef.Schema)),
        multiKeyIndexing = schema.Optional(schema.Collection(NameRef.Schema)),
    }),

    --[[
    User defined arbitrary data (UI generation rules etc)
     ]]
    meta = schema.Any,

    accessRules = schema.Optional(AccessControl.Schema),
}

-- Schema for multi class JSON
ClassDef.MultiClassSchema = schema.Map(name_ref.IdentifierSchema, ClassDef.Schema)

return ClassDef
