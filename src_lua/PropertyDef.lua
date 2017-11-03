---
--- Created by slanska.
--- DateTime: 2017-10-31 3:18 PM
---

--[[
Property definition
Keeps name, id, reference to class definition

]]

require 'math'

local PropertyDef = {}

function PropertyDef:new(ClassDef, name)
    local result = {
        ClassDef = ClassDef,
        name = name
    }

    setmetatable(result, self)
    self.__index = self

    return result
end

function PropertyDef:save()
    assert(self.ClassDef and self.ClassDef.DBContext)

    local stmt = self.ClassDef.DBContext.getStatement [[

    ]]

    stmt:bind {}
    local result = stmt:step()
    if result ~= 0 then
        -- todo error
    end
end

function PropertyDef:selfValidate()
    -- todo
end

return PropertyDef