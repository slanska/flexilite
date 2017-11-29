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

local PropertyDef = require('PropertyDef')
local name_ref = require('NameRef')
local NameRef = name_ref.NameRef

--[[

]]

---@class ClassDef
local ClassDef = {}

---
---@private
---@param self ClassDef
---@param data table @comment As it is stored in [.classes].Data
local function fromJSON(self, data)
    -- Properties by name
    self.Properties = {}
    -- Properties by ID
    self.PropertiesByID = {}
    self.Name = {}
    setmetatable(self.Name, NameRef)

    --[[ This function can be called in 2 contexts:
     1) from raw JSON, during create/alter class/property
     2) from database saved
     in (1) nameOrId will be property name (string), property def will not have name or name id
     in (2) nameOrId will be property id (number), property def will have name and name id
    ]]
    for nameOrId, p in pairs(data.properties) do
        if not self.Properties[p.ID] then
            local prop = PropertyDef.import(self, p)

            -- Determine mode
            if type(nameOrId) == 'number' and p.Prop.name and p.Prop.id then
                -- Database contexts
                self.PropertiesByID[nameOrId] = prop
                self.Properties[p.Prop.name] = prop
            else
                if type(nameOrId) ~= 'string' then
                    error('Invalid type of property name: ' .. nameOrId)
                end

                -- Raw JSON context
                prop.Prop.name = nameOrId
                self.Properties[nameOrId] = prop

                -- TODO temp
                if prop.D.refDef and prop.D.refDef.classRef then
                    print("initMetadataRefs: " .. prop.Prop.name .. ", classRef: ", prop.D.refDef.classRef)

                end
            end
        end
    end

    ---@param dictName string
    local function dictFromJSON(dictName)
        self[dictName] = {}
        local tt = data[dictName]
        if tt then
            for k, v in pairs(tt) do
                if type(v) ~= 'table' then
                    v = { name = v }
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

--- Loads class definition from database
---@public
---@param DBContext DBContext
---@param classObj table
--- (optional)
function ClassDef:loadFromDB (DBContext, classObj)
    assert(classObj)
    setmetatable(classObj, self)
    self.__index = self
    classObj.DBContext = DBContext
    classObj:fromJSON(classObj.Data)
    classObj.Data = nil
    return classObj
end

-- Initializes raw table (normally loaded from database) as ClassDef object
---@public
---@param DBContext DBContext
---@param json table
function ClassDef:fromJSON(DBContext, data)
    local obj = {
        DBContext = DBContext
    }
    setmetatable(obj, self)
    self.__index = self
    fromJSON(obj, data)
    return obj
end

---@param DBContext DBContext
---@param jsonString string
---@return ClassDef
function ClassDef:fromJSONString(DBContext, jsonString)
    if type(jsonString) == 'table' then
        return self:fromJSON(DBContext, jsonString)
    end
    return self:fromJSON(DBContext, json.decode(jsonString))
end

function ClassDef:selfValidate()
    -- todo implement
end

function ClassDef:hasProperty(idOrName)
    return self.Properties[idOrName]
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
        name = self.Name,
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
---@return table
function ClassDef:internalToJSON()
    local result = {}

    for propID, prop in pairs(self.PropertiesByID) do
        result[tostring(propID)] = prop:internalToJSON()
    end

    -- TODO Other attributes?

    return result
end

return ClassDef

