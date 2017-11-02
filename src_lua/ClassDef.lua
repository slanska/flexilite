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

function ClassDef:new (DBContext, name)

    -- TODO validate name

    local result = {
        DBContext = DBContext,
        Name = name,

        -- Properties are stored twice - by ID and by Name
        Properties = {} }

    setmetatable(result, self)
    self.__index = self
    return result
end

function ClassDef:load()
    local stmt = self.DBContext:getStatement [[

    ]]
    stmt:bind{}
end

function ClassDef:selfValidate()
    -- todo implement
end

function ClassDef:hasProperty(idOrName)
    local prop = self.Properties[idOrName]
    return prop ~= nil, prop
end

-- Internal function to add property
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

return ClassDef

