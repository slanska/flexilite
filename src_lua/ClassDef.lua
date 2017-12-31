---
--- Created by slanska.
--- DateTime: 2017-10-31 3:10 PM
---

--[[
Flexilite class (=table) definition
Has reference to DBContext
Corresponds to [.classes] database table + D - decoded [data] field, with initialized PropertyRef's and NameRef's

Find property
Validates class structure
Loads class def from DB
Validates existing data with new class definition
]]

local json = require 'cjson'
local schema = require 'schema'
local Util64 = require 'Util'
local Constants = require 'Constants'
local PropertyDef = require('PropertyDef')
local name_ref = require('NameRef')
local NameRef = name_ref.NameRef
local class = require 'pl.class'
local tablex = require 'pl.tablex'
local AccessControl = require 'AccessControl'
local bit = type(jit) == 'table' and require('bit') or require('bit32')

--[[
Index definitions for class. Operate with property IDs only,
so properties of new class must be saved prior to using this class.
Used for:
a) organizing indexes, e.g. eliminating duplicates in index definition
b) finding best index
c) applying changes for index storage
]]

---@class IndexDefinitions
local IndexDefinitions = class()

-- Internal static variables
IndexDefinitions.ftsCols = { 'X1', 'X2', 'X3', 'X4', 'X5' }
IndexDefinitions.rngCols = { 'A0', 'A1', 'B0', 'B1', 'C0', 'C1', 'D0', 'D1', 'E0', 'E1' }

function IndexDefinitions:_init()
    -- Full text index. Array 1..5 to property ID (1 = X1, 2 = X2 ...)
    self.fullTextIndexing = {}

    -- Range index. Array 1 .. 10 to property ID (1 = A0, 2 = A1, 3 = B0...)
    self.rangeIndexing = {}

    -- Multi property unique indexes. Map of 2, 3, 4 to array of property IDs
    self.multiKeyIndexing = { [2] = {}, [3] = {}, [4] = {} }

    -- Indexes for single properties. Map by property ID to boolean
    -- (false - non-unique index, true - unique index)
    self.propIndexing = {}
end

---@param propDef PropertyDef
---@return boolean, string @comment true if ok, false and error message if failed
function IndexDefinitions:AddFullTextIndexedProperty(propDef)
    assert(propDef and propDef.ID)

    local supportedIndexTypes = propDef:GetSupportedIndexTypes()
    if bit.BAnd(supportedIndexTypes, Constants.INDEX_TYPES.FTS) ~= Constants.INDEX_TYPES.FTS then
        return false, string.format('Property [%s] does not support full text indexing', propDef.Name.text)
    end

    -- Already set?
    local existingIndex = tablex.find(self.fullTextIndexing, propDef.ID)
    if existingIndex then
        return true, nil
    end

    if #self.fullTextIndexing == 5 then
        return false, 'Maximum number of properties in full text index (5) exceeded'
    end
    table.insert(self.fullTextIndexing, propDef.ID)
    return true, nil
end

---@param propDef0 PropertyDef
---@param propDef1 PropertyDef
---@return boolean, string @comment true if ok, false and error message if failed
function IndexDefinitions:AddRangeIndexedProperties(propDef0, propDef1)
    assert(propDef0 and propDef0.ID)

    propDef1 = propDef1 or propDef0

    for _, propDef in ipairs({ propDef0, propDef1 }) do
        local supportedIndexTypes = propDef:GetSupportedIndexTypes()
        if bit.BAnd(supportedIndexTypes, Constants.INDEX_TYPES.RNG) ~= Constants.INDEX_TYPES.RNG then
            return false, string.format('Property [%s] does not support range indexing', propDef.Name.text)
        end

        if tablex.find(self.rangeIndexing, propDef.ID) then
            return true, nil
        end
    end

    if #self.rangeIndexing == 10 then
        return false, 'Maximum number of dimensions in range index (5) exceeded'
    end

    table.insert(self.rangeIndexing, propDef0.ID)
    table.insert(self.rangeIndexing, propDef1.ID)
    return true, nil
end

---@param propDefs table @comment array of PropertyDef
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
        if bit.BAnd(supportedIndexTypes, Constants.INDEX_TYPES.MUL) ~= Constants.INDEX_TYPES.MUL then
            return false, string.format('Property [%s] does not support multi key indexing', propDef.Name.text)
        end

        -- Check for accidental duplicates
        local all = tables.imap(function(p)
            return p.ID == propDefID
        end, propDefs)

        if #all > 1 then
            return false, string.format('Property [%s] is repeated more than once in multi key index', propDef.Name.text)
        end
    end

    self.multiKeyIndexing[len] = tablex.imap(function(propDef)
        return propDef.ID
    end, propDefs)

    return true, nil
end

---@param propDef PropertyDef
---@param unique boolean
---@return boolean, string @comment true if ok, false and error message if failed
function IndexDefinitions:AddIndexedProperty(propDef, unique)
    assert(propDef and propDef.ID)

    local supportedIndexTypes = propDef:GetSupportedIndexTypes()
    local expectedIndexType = unique and Constants.INDEX_TYPES.UNQ or Constants.INDEX_TYPES.STD
    if bit.BAnd(supportedIndexTypes, expectedIndexType) ~= expectedIndexType then
        return false, string.format('Property [%s] does not support indexing', propDef.Name.text)
    end

    if not unique then
        -- Find possible usage of the same property in other types of indexes
        local idx = tablex.find(self.rangeIndexing, propDef.ID)
        if idx then
            table.remove(self.propIndexing, propDef.ID)
            return true, string.format('Property %s already included in range index', propDef.Name.text)
        end

        idx = tablex.find_if(function(propIDs)
            return propIDs[1] == propDef.ID
        end, self.multiKeyIndexing)
        if idx then
            table.remove(self.propIndexing, propDef.ID)
            return true, string.format('Property %s already included in multi key index', propDef.Name.text)
        end
    end

    self.propIndexing[propDef.ID] = unique
end

function IndexDefinitions:__eq(A, B)
    return tablex.deepcompare(A, B)
end

-- Processed indexing for individual property
---@param propDef PropertyDef
---@return boolean, string @comment true if ok, false and error message if failed
function IndexDefinitions:SetPropertyIndex(propDef)
    assert(propDef and propDef.ID)

    local idxType = string.lower(propDef.index or '')
    if idxType == '' then
        if self.propIndexing[propDef.ID] then
            table.remove(self.propIndexing, propDef.ID)
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



--[[

]]

---@class ClassDef
local ClassDef = class()

--- ClassDef constructor
---@param params table @comment {DBContext: DBContext, newClassName:string, data: table | string | table as parsed json}
function ClassDef:_init(params)
    self.DBContext = params.DBContext

    --[[ Properties by name
    Lookup by property name. Includes class own properties
    ]]
    self.Properties = {}

    -- Properties from mixin classes, by name
    -- Values are lists of PropertyDef
    self.MixinProperties = {}

    -- set column mapping dictionary, value is either nil or PropertyDef
    self.propColMap = { }

    self.CheckedInTrn = 0

    -- Object schema (for create and update operations)
    self.objectSchema = {}

    self.indexes = IndexDefinitions()

    local data

    if params.newClassName then
        -- New class initialization. params.data is either string or JSON
        -- and it is JSON with class definition
        data = params.data
        if type(data) == 'string' then
            data = json.decode(data)
        end

        -- Class name reference
        self.Name = NameRef(nil, params.newClassName)
        self.D = {}

        for propName, propJsonData in pairs(data.properties) do
            self:AddNewProperty(propName, propJsonData)
        end
    else
        -- Loading existing class from DB. params.data is [.classes] row
        assert(type(params.data) == 'table')
        self.Name = NameRef(params.data.NameID, params.data.Name)
        self.ClassID = params.data.ClassID
        self.ctloMask = params.data.ctloMask
        self.SystemClass = params.data.SystemClass
        self.VirtualTable = params.data.VirtualTable
        self.Deleted = params.data.Deleted
        self.ColMapActive = params.data.ColMapActive
        self.vtypes = params.data.vtypes

        self.D = json.decode(params.data.Data)
        data = self.D

        -- Load from .class_props
        for propRow in self.DBContext:loadRows([[
        select PropertyID, ClassID, NameID, Property, ctlv, ctlvPlan,
            Deleted, SearchHitCount, NotNullCount from [.class_props] cp where cp.ClassID = :ClassID;]],
        { ClassID = self.ClassID }) do
            self:loadPropertyFromDB(propRow, self.D.properties[propRow.PropertyID])
        end
    end

    ---@param dictName string
    local function dictFromJSON(dictName)
        self[dictName] = {}
        local tt = data[dictName]
        if tt then
            for k, v in pairs(tt) do
                if type(v) ~= 'table' then
                    v = { text = v }
                end
                setmetatable(v, NameRef)
                self[dictName][k] = v
            end
        end
    end

    dictFromJSON('specialProperties')
    dictFromJSON('rangeIndexing')
    dictFromJSON('fullTextIndexing')
end

-- Initializes existing property loaded from database. Internally used method
---@param dbrow table @comment flexi_prop view structure
---@param propJsonData table @comment property definition according to schema
function ClassDef:loadPropertyFromDB(dbrow, propJsonData)
    local prop = PropertyDef.CreateInstance { ClassDef = self, dbrow = dbrow, jsonData = propJsonData }
    self.Properties[dbrow.Name] = prop
end

-- Internal method to add property definition to the property list
-- Called when a) creating a new class, b) loading existing class from DB,
-- c) altering existing class
---@param propName string
---@param propJsonData table @comment parsed JSON for property definition
function ClassDef:AddNewProperty(propName, propJsonData)
    local prop = PropertyDef.CreateInstance { ClassDef = self, newPropertyName = propName, jsonData = propJsonData }
    self.Properties[propName] = prop
end

-- Fills MixinProperties with properties from mixin classes, if applicable
function ClassDef:initMixinProperties()
    self.MixinProperties = {}
    for _, pp in pairs(self.Properties) do
        if pp:is_a(PropertyDef.PropertyTypes['mixin']) then
            assert(pp.refDef and pp.refDef.classRef)
            local mixin = self.DBContext:getClassDef(pp.refDef.classRef.ID)

            for _, mp in pairs(mixin.Properties) do
                local d = self.MixinProperties[mp.Name.text]
                if not d then
                    d = {}
                    self.MixinProperties[mp.Name.text] = d
                end
                table.insert(d, mp)
            end
        end
    end
end

-- Attempts to assign column mapping
---@param prop IPropertyDef
---@return bool
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
function ClassDef:getProperty(propName)
    -- Check if exists
    local prop = self:hasProperty(propName)
    if not prop then
        error( "Property " .. tostring(propName) .. " not found or ambiguous")
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
---@return table
function ClassDef:internalToJSON()
    local result = { properties = {} }

    for _, prop in pairs(self.Properties) do
        result.properties[tostring(prop.PropertyID)] = prop:internalToJSON()
    end

    -- TODO Other attributes?

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
    local result = self.DBContext.db:exec(sql)
    if result ~= 0 then
        local errMsg = string.format("%d: %s", self.DBContext.db:error_code(), self.DBContext.db:error_message())
        error(errMsg)
    end
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

-- Updated class definition in database. Is is expected to be already created
-- (INSERT INTO already run and class ID is known)
function ClassDef:saveToDB()
    assert(self.ClassID > 0)
    local internalJson = json.encode(self:internalToJSON())

    -- Calculate ctloMask and vtypes
    self.vtypes = 0
    self.ctloMask = 0
    for _, propDef in pairs(self.propColMap) do
        assert(propDef)
        local colIdx = string.lower(propDef.ColMap):byte() - string.byte('a')
        local vtmask = Util64.BNot64(Util64.BLShift64(7, colIdx * 3))
        local vtype = Util64.BLShift64(propDef:GetVType(), colIdx * 3)

        self.vtypes = Util64.BSet64(self.vtypes, vtmask, vtype)

        if propDef.index == 'unique' then
            local idxMask = Util64.BNot64(Util64.BLShift64(1, colIdx + Constants.CTLO_FLAGS.UNIQUE_SHIFT))
            self.ctloMask = Util64.BSet64(self.ctloMask, idxMask, 1)
        elseif propDef.index == 'index' then
            -- TODO Check if property should be indexed
            local idxMask = Util64.BNot64(Util64.BLShift64(1, colIdx + Constants.CTLO_FLAGS.INDEX_SHIFT))
            self.ctloMask = Util64.BSet64(self.ctloMask, idxMask, 1)
        end
    end

    self:execStatement([[update [.classes] set NameID = :NameID, Data = :Data,
        ctloMask = :ctloMask, vtypes = :vtypes where ClassID = :ClassID;]],
    {
        NameID = self.Name.id,
        Data = internalJson,
        ctloMask = self.ctloMask,
        vtypes = self.vtypes,
        ClassID = self.ClassID
    })
end

-- Checks all properties and determines the best index to be used
-- Indexes may be defined on individual properties level as well as on class level ('indexes' )
-- Properties must be already saved, i.e. must have property IDs assigned
-- Also validates index definitions
-- Used to optimize index definitions and also to prepare differences in indexes for AlTER CLASS/ALTER

---@return IndexDefinitions
function ClassDef:getIndexDefinitions()
    local result = IndexDefinitions()

    for indexName, indexDef in pairs(self.D.indexes) do
        local indexType = string.lower( indexDef.type or 'index')
        local props = indexDef.properties
        if type(props) == 'string' then
            props = { name_ref.PropertyRef(nil, props) }
            props[1]:resolve(self)
        else
            if type(props) ~= 'table' then
                props = { props }
            end
            props = tables.map(function(pp)
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
                error(string.format('Invalid number of keys in unique/multi key index' ))
            else
                local propDef = self:getProperty(props[1].text)
                local ok, msg = result:AddIndexedProperty(propDef, true)
                if not ok then
                    error(msg)
                end
            end
        elseif indexType == 'fulltext' then
            for i, propRef in ipairs(props) do
                local propDef = self:getProperty(propRef.text)
                local ok, msg = result:AddFullTextIndexedProperty(propDef)
                if not ok then
                    error(msg)
                end
            end
        elseif indexType == 'index' then
            -- if 2..5 properties in the list, there is attempt to apply range index
            -- otherwise, apply individual indexing

        end
    end

    return result
end

-- Potentially long operation to update indexes (drop, create, update etc.)
function ClassDef:ApplyIndexing()

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
            objSchema[propName] = schema.Optional(propSchema)
        else
            objSchema[propName] = propSchema
        end
    end

    -- mixin properties which do not duplicate own properties
    -- they can be accessed as own properties
    for propName, propDefs in pairs(self.MixinProperties) do
        if not objSchema[propName] and #propDefs == 1 then
            local propSchema = propDefs[1]:GetValueSchema(op)
            if op == 'U' then
                objSchema[propName] = schema.Optional(propSchema)
            else
                objSchema[propName] = propSchema
            end
        end
    end

    result = schema.Record(objSchema, self.allowAnyProps)
    self.objectSchema[op] = result
    return result
end

local IndexPropertySchema = schema.Record {
    id = schema.Optional(schema.AllOf(schema.Integer, schema.PositiveNumber)),
    text = name_ref.IdentifierSchema,
    desc = schema.Optional(schema.Boolean)
}

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

    rangeIndexing = schema.Optional(schema.Record {
        A0 = schema.Optional(NameRef.Schema),
        A1 = schema.Optional(NameRef.Schema),
        B0 = schema.Optional(NameRef.Schema),
        B1 = schema.Optional(NameRef.Schema),
        C0 = schema.Optional(NameRef.Schema),
        C1 = schema.Optional(NameRef.Schema),
        D0 = schema.Optional(NameRef.Schema),
        D1 = schema.Optional(NameRef.Schema),
        E0 = schema.Optional(NameRef.Schema),
        E1 = schema.Optional(NameRef.Schema),
    }),

    --[[
    Optional full text indexing. Maximum 4 properties are allowed for full text index.
    These properties are mapped to X1-X5 columns in [.full_text_data] table
    ]]
    fullTextIndexing = schema.Optional(schema.Record {
        X1 = schema.Optional(NameRef.Schema),
        X2 = schema.Optional(NameRef.Schema),
        X3 = schema.Optional(NameRef.Schema),
        X4 = schema.Optional(NameRef.Schema),
        X5 = schema.Optional(NameRef.Schema),
    }),

    --[[
    Alternative way to define indexes (in addition to property's indexing)
        Also, this is the only way to define multi-column unique indexes
        'range' and 'fulltext' indexes are merged and resulting number of columns must not
        exceed limits (5 full text columns and 5 dimensions for range index)
        'range' indexes must be defined in pairs (even number of properties, i.e. 2, 4, 6, 8 or 10)
        keys in this tables (aka 'index name') are ignored
        ]]
    indexes = schema.Optional(schema.Map(schema.String, schema.Record {
        type = schema.OneOf(schema.Nil, 'index', 'unique', 'range', 'fulltext'),
        properties = schema.OneOf(
        NameRef.Schema,
        schema.String,
        schema.Collection(IndexPropertySchema)),
    })),

    --[[
    User defined arbitrary data (UI generation rules etc)
     ]]
    meta = schema.Any,

    accessRules = schema.Optional(AccessControl.Schema)
}

-- Schema for multi class JSON
ClassDef.MultiClassSchema = schema.Map(name_ref.IdentifierSchema, ClassDef.Schema)

return ClassDef