---
--- Created by slanska.
--- DateTime: 2017-10-31 3:20 PM
---

local class = require 'pl.class'

local schema = require 'schema'

-- define schema for name definition
local nameSchema = schema.Record {
    id = schema.Number,
    name = schema.String
}

--[[
NameRef class.
Properties:
name
id
]]

---Abstract base class for name dereference
---@class MetadataRef
local MetadataRef = class()

---@param name string
---@param id number
function MetadataRef:_init(name, id)
    self.name = name
    self.id = id
end

--- '==' operator for name refs
---@overload
---@param a MetadataRef
---@param b MetadataRef
function MetadataRef.__eq (a, b)
    if getmetatable(a) ~= getmetatable(b) then
        return false
    end
    if a.id and b.id and a.id == b.id then
        return true
    end
    return a.name and b.name and a.name == b.name
end

local NameRef = class(MetadataRef)

--- Ensures that class with given name/id exists (uses classDef.DBContext
---@param classDef ClassDef
function NameRef:resolve(classDef)
    -- TODO create name
    if not self.id then
        self.id = classDef.DBContext:ensureName(self.name)
    end
end

function MetadataRef:validate()
    schema.CheckSchema(self, nameSchema())
end

---@param classDef ClassDef
function NameRef:isResolved(classDef)
    return self.id ~= nil
end

---@return table
function NameRef:export()
    return self
end

local ClassNameRef = class(MetadataRef)

---@param classDef ClassDef
function ClassNameRef:resolve(classDef)
    if self.id or self.name then
        local cc = classDef.DBContext:LoadClassDefinition(self.id and self.id or self.name)
        if cc ~= nil then
            self.id = cc.ClassID
        else
            self.id = nil
        end
    else
        error 'Neither name nor id are defined in class name reference'
    end
end

---@param classDef ClassDef
function ClassNameRef:isResolved(classDef)
    return type(self.id) == 'number'
end

local PropNameRef = class(MetadataRef)

--- Ensures that class owner has given property (by name/id)
---@param classDef ClassDef
function PropNameRef:resolve(classDef)
    -- will throw error is property does not exist
    if not self.id then
        local pp = classDef:getProperty(self.name)
        self.id = pp.id
    end
end

---@param classDef ClassDef
function PropNameRef:isResolved(classDef)
    local pp = classDef.Properties[self.id and self.id or self.name]
    return pp ~= nil
end

return { NameRef = NameRef, ClassNameRef = ClassNameRef, PropNameRef = PropNameRef }