---
--- Created by slanska.
--- DateTime: 2017-12-19 7:13 AM
---

--[[
User exposed instance of [.object] record to be run in sandboxed mode.
Follows access rules, supports read-only mode, applies constraints & default values,
validates data before saving etc.
Used to provide access to data from custom functions and triggers

Every ApiObject keeps its own reference to DBObject instance, for low level db operations

]]

local class = require 'pl.class'
local DBObject = require 'DBObject'

---@class ApiObject
local ApiObject = class()

---@param obj ApiObject
local function ApiObjectProxy(obj)

    local self = setmetatable({}, {
        __index = function(idx)
            return obj:getPropValue(idx)
        end,

        __newindex = function(idx, val)
            return obj:setPropValue(idx, val)
        end,

        __metatable = function()
            return nil
        end
    })

    return self
end

---@param classDef IClassDef
---@param objectId number @comment optional, Int64
function ApiObject:_init(classDef, objectId)
    ---@type ClassDef
    self.ClassDef = classDef

    self.ID = objectId

    ---@type DBObject
    self.DBObject = DBObject(classDef, objectId)
end

function ApiObject:GetProxy()
    if not self.proxy then
        self.proxy = ApiObjectProxy(self)
    end

    return self.proxy
end

-- Handles object's properties
function ApiObject:__index(idx)
    if type(idx) == 'string' then
        -- Property name
    else
    end
end

function ApiObject:__newindex(idx, val)
    if type(idx) == 'string' then
    else
    end
end

-- Hide metadata
function ApiObject:__metadata()
    return nil
end

---@param data table
function ApiObject:SetData(data)

end

---@return table
function ApiObject:GetData()

end

---@param propName string
---@return ApiValue
function ApiObject:getPropValue(propName)
    ---@type PropertyDef
    local propDef = self.ClassDef:getProperty(propName)
    local vals = self.DBObject:getRefValue(propDef.ID, 1)

end

---@param propName string
---@param value ApiValue
function ApiObject:setPropValue(propName, value)

end

return ApiObject