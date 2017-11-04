---
--- Created by slan_ska.
--- DateTime: 2017-10-31 3:10 PM
---

--[[
Class definition
Has reference to DBContext
Collection of properties
Find property
Validates class structure
Loads class def from DB
Validates existing data with new class definition
]]

local PropertyDef = require('PropertyDef')
local NameRef = require('NameRef')

local ClassDef = {}

--- Creates new instance of ClassDef
--- Internal method. Sets DBContext to class def instance, but does not add it to DBContext.Classes
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

function ClassDef:toJSON()
    
end

return ClassDef

