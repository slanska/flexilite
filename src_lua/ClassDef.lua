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

local PropertyDef = require('PropertyDef')
local NameRef = require('NameRef')

--[[

]]

---@class ClassDef
local ClassDef = {}

---@private
---@param self ClassDef
---@param json string @comment As it is stored in [.classes].Data
local function fromJSON(self, json)
    local dd = json.decode(json)

    self.Properties = {}

    for k, p in pairs(dd.properties) do
        if not self.Properties[p.ID] then
            local prop = PropertyDef:fromJSON(self, p)
            self.Properties[p.Name] = prop
            self.Properties[p.ID] = prop
        end
    end

    ---@param dictName string
    function dictFromJSON(dictName)
        self[dictName] = {}
        local tt = dd[dictName]
        if tt then
            for k, v in pairs(tt) do
                self[dictName][k] = NameRef:fromJSON(self.DBContext, Bv)
            end
        end
    end

    dictToJSON('specialProperties')
    dictToJSON('rangeIndexing')
    dictToJSON('fullTextIndexing')
    dictToJSON('columnMapping')
end

--- Loads class definition from database
---@public
---@param DBContext DBContext
---@param obj table
--- (optional)
function ClassDef:loadFromDB (DBContext, obj)
    assert(obj)
    setmetatable(obj, self)
    self.__index = self
    obj.DBContext = DBContext
    obj:fromJSON(obj.Data)
    obj.Data = nil
    return obj
end

-- Initializes raw table (normally loaded from database) as ClassDef object
---@public
---@param DBContext DBContext
---@param json string
function ClassDef:fromJSON(DBContext, json)
    local obj = {
        DBContext = DBContext
    }
    setmetatable(obj, self)
    self.__index = self
    fromJSON(self, json)
    return obj
end

---@param DBContext DBContext
---@param jsonString string
---@return ClassDef
function ClassDef:fromJSONString(DBContext, jsonString)
    return self:fromJSON(DBContext, json.decode(jsonString))
end

function ClassDef:selfValidate()
    -- todo implement
end

function ClassDef:hasProperty(idOrName)
    local prop = self.Properties[idOrName]
    return prop ~= nil, prop
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
    local exists, prop = self.hasProperty(idOrName)
    if not exists then
        error( "Property " .. tostring(idOrName) .. " not found")
    end
    return self.Properties[idOrName]
end

function ClassDef:validateData()
    -- todo
end

---@return table @comment User friendly encoded JSON of class definition (excluding raw and internal properties)
function ClassDef:toJSON()
    local result = {
        id = self.ID,
        name = self.Name,
        allowAnyProps = self.D.allowAnyProps,
    }

    ---@return nil
    function dictToJSON(dictName)
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

return ClassDef

