---
--- Created by slan_ska.
--- DateTime: 2017-10-31 3:10 PM
---

--[[
Flexilite class (table) definition
Has reference to DBContext
Corresponds to [.classes] database table + D - decoded [data] field, with initialized PropertyRef's and NameRef's

Find property
Validates class structure
Loads class def from DB
Validates existing data with new class definition
]]

local json = require 'cjson'

local schema = require 'schema'

-- define schema for class definition
local classSchema = schema.Record {

}

local PropertyDef = require('PropertyDef')
local name_ref = require('NameRef')
local NameRef = name_ref.NameRef
local class = require 'pl.class'
local tablex = require 'pl.tablex'

--[[

]]

---@class ClassDef
local ClassDef = class()

--- ClassDef constructor
---@param params table @comment {DBContext, newClassName, data: table | string | json}
function ClassDef:_init(params)
    self.DBContext = params.DBContext

    -- Properties by name
    self.Properties = {}
    -- Properties by ID
    self.PropertiesByID = {}
    self.Name = {}

    -- set column mapping dictionary
    self.propColMap = {
        A = false, B = false, C = false, D = false, E = false, F = false, G = false, H = false,
        I = false, J = false, K = false, L = false, M = false, N = false, O = false, P = false
    }

    self.AccessRules = {}
    self.CheckedInTrn = 0

    setmetatable(self.Name, NameRef)
    local data

    if params.newClassName then
        -- New class initialization. params.data is either string or JSON
        data = params.data
        if type(data) == 'string' then
            data = json.decode(params.data)
        end

        self.Name.text = params.newClassName
        self.D = {}
    else
        -- Loading existing class from DB. params.data is [.classes] row
        -- todo confirm class def structure
        assert(type(params.data) == 'table')
        self.Name.id = params.data.NameID
        self.Name.text = params.data.Name
        self.ClassID = params.data.ClassID

        self.D = params.data
        data = json.decode(params.data.Data)
    end

    for nameOrId, p in pairs(data.properties) do
        --if not self.Properties[p.ID] then
        local prop = PropertyDef.CreateInstance(self, p)

        -- Determine mode
        if type(nameOrId) == 'number' and p.Prop.text and p.Prop.id then
            -- Database contexts
            self.PropertiesByID[nameOrId] = prop
            self.Properties[p.Prop.text] = prop
        else
            if type(nameOrId) ~= 'string' then
                error('Invalid type of property name: ' .. nameOrId)
            end

            -- Raw JSON context
            prop.Prop.text = nameOrId
            self.Properties[nameOrId] = prop
        end

        if p.ColMap then
            self.propColMap[p.ColMap] = p
        end

        --end
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
    dictFromJSON('columnMapping')
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
    local ch = tablex.find_if(self.propColMap, function(val)
        return not val
    end )

    -- Assigned!
    if ch then
        self.propColMap[ch] = prop
        prop.ColMap = ch
        return true
    end

    return false
end

function ClassDef:selfValidate()
    -- todo implement
end

function ClassDef:hasProperty(idOrName)
    if type(idOrName) == 'string' then
        return self.Properties[idOrName]
    end
    return self.PropertiesByID[idOrName]
end

-- Internal function to add property to properties collection
---@param propDef PropertyDef
function ClassDef:addProperty(propDef)
    assert(propDef)
    assert(type(propDef.ID) == 'number')
    assert(type(propDef.Name) == 'string')
    self.Properties[propDef.ID] = propDef
    self.Properties[propDef.Name] = propDef
end

function ClassDef:getProperty(idOrName)
    -- Check if exists
    local prop = self.hasProperty(idOrName)
    if not prop then
        error( "Property " .. tostring(idOrName) .. " not found")
    end
    return prop
end

function ClassDef:validateData()
    -- todo
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

    for i, p in ipairs(self.Properties) do
        result[p.Name] = p.toJSON()
    end

    dictToJSON('specialProperties')
    dictToJSON('fullTextIndexing')
    dictToJSON('rangeIndexing')
    dictToJSON('columnMapping')

    return result
end

--- Returns internal representation of class definition, as it is stored in [.classes] db table
---Properties are indexed by property IDs
---@return table
function ClassDef:internalToJSON()
    local result = { properties = {} }

    for propID, prop in pairs(self.PropertiesByID) do
        result.properties[tostring(propID)] = prop:internalToJSON()
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

return ClassDef