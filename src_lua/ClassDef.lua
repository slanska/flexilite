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
--local tablex = require 'pl.tablex'
local AccessControl = require 'AccessControl'

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

    self:execStatement("update [.classes] set NameID = :1, Data = :2, ctloMask = :3, vtypes = :4 where ClassID = :5;",
    {
        ['1'] = self.Name.id,
        ['2'] = internalJson,
        ['3'] = self.ctloMask,
        ['4'] = self.vtypes,
        ['5'] = self.ClassID
    })
end

-- Checks all properties and determines the best index to be used
-- Also validates index definitions
function ClassDef:organizeIndexes()

    -- Single key non unique indexes
    -- Exclude columns that are in a) range index already, b) first column in multi key indexes
    -- Number, integers, datetime, symnames - candidates for range index (if there are slots)

    -- Multi key unique indexes

    -- Full text indexes
    -- Validate

    -- Single key unique indexes

    -- Range indexes
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
    These properties are mapped to X1-X4 columns in [.full_text_data] table
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
        Also, used for multi-column unique indexes
        ]]
    indexes = schema.Optional(schema.Map(schema.String, schema.Record {
        type = schema.OneOf(schema.Nil, 'index', 'unique', 'range', 'fulltext'),
        properties = schema.OneOf(
        NameRef.Schema,
        schema.String,
        schema.Collection(        IndexPropertySchema        )),
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