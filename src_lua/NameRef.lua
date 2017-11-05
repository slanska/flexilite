---
--- Created by slanska.
--- DateTime: 2017-10-31 3:20 PM
---

--[[
NameRef class.
Provides access to name ID via name
]]

---@class NameRef
local NameRef = {}

---@param DBContext DBContext
---@param name string @comment Name referenced
function NameRef:new(DBContext, name)
    assert(DBContext)
    local result = {
        DBContext = DBContext
    }
    setmetatable(result, self)
    self.__index = self
    return result
end

---@return string @comment Returns name text by its id. Throws error if id is not set or does not exist
function NameRef:getName()

end

---@param ensure boolean @comment If true, name will be created in database
---@return number @comment Returns name ID by its text. May be null, if name does not exist and ensure is false
function NameRef:getID(ensure)

end

---@return table
function NameRef:toJSON()
    return self
end

return NameRef