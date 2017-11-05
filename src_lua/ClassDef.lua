---
--- Created by slan_ska.
--- DateTime: 2017-10-31 3:10 PM
---

--[[
Flexilite class (table) definition
Has reference to DBContext
Corresponds to [.classes] database table + decoded [data] field, with initialized PropertyRef's and NameRef's

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

--- Creates new unsaved instance of ClassDef
--- Internal method. Sets DBContext to class def instance, but does not add it to DBContext.Classes
--- Used for new class initialization and class alteration
---@param DBContext DBContext
---@param name string
--- (optional)
function ClassDef:new (DBContext, name)
    local result = {
        DBContext = DBContext,
        Name = name,

        -- Properties are stored twice - by ID and by Name
        Properties = {} }

    setmetatable(result, self)
    self.__index = self
    return result
end

-- Initializes raw table (normally loaded from database) as ClassDef object
---@param DBContext DBContext
---@param instance table
function ClassDef:init(DBContext, instance)
    assert(instance)
    setmetatable(instance, self)
    self.__index = self
    instance.DBContext = DBContext
    return instance
end

-- Internally used constructor to create ClassDef from class definition table parsed from JSON
---@param DBContext DBContext
---@param json table
-- (proto-object of ClassDef)
function ClassDef:fromJSON(DBContext, json)
    json.DBContext = DBContext
    setmetatable(json, self)
    self.__index = self
    return json
end

-- TODO
function ClassDef:load()
    local stmt = self.DBContext:getStatement [[

    ]]
    stmt:bind {}
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

---@return table @comment User friendly stringified JSON of class definition (excluding raw and internal properties)
function ClassDef:toJSON()
    local result = {
        id = self.ID,
        name = self.Name,
        allowAnyProps = self.allowAnyProps,
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

