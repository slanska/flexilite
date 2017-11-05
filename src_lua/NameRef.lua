---
--- Created by slanska.
--- DateTime: 2017-10-31 3:20 PM
---

--[[
NameRef class.
Properties:
name
id
]]

---@class NameRef
local NameRef = {
    ---@param a NameRef
    ---@param b NameRef
    __eq = function(a, b)
        return a.id == b.id or a.name == b.name
    end
}

---@param DBContext DBContext
---@param name string @comment Name referenced
function NameRef:fromJSON(DBContext, obj)
    assert(DBContext)
    setmetatable(obj, self)
    self.__index = self
    obj. DBContext = DBContext
    return obj
end

---@return string @comment Returns name text by its id. Throws error if id is not set or does not exist
function NameRef:getName()
    assert(self.id)
end

---@param ensure boolean @comment If true, name will be created in database
---@return number @comment Returns name ID by its text. May be null, if name does not exist and ensure is false
function NameRef:getID(ensure)
    assert(self.name)
end

---@return table
function NameRef:toJSON()
    return {
        id = self.id,
        name = self.name
    }
end

return NameRef