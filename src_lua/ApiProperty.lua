---
--- Created by slanska.
--- DateTime: 2017-12-20 7:20 PM
---

--[[
Access to object property value to be used in user's custom
functions and triggers.
Implements all table metamethods to mimic functionality of real property,
so that Order.ShipDate or Order.OrderLines[1] will look as real object
properties.

Internally uses DBRefValue to manipulate with data.
Uses AccessControl to check access rules
]]

local class = require('pl.class')

---@class ApiProperty
local ApiProperty = class()

-- Constructor
---@param propDef PropertyDef
---@param object ApiObject
function ApiProperty:_new(propDef, object)
    self.propDef = propDef
    self.object = object
end

-- Hide metadata
function ApiProperty:__metadata()
    return nil
end

function ApiProperty:__index(key)

end

function ApiProperty:__newindex(key, value)

end

function ApiProperty:__tostring()

end

function ApiProperty:__len()

end

function ApiProperty:__unm()

end

function ApiProperty:__add()

end

function ApiProperty:__sub()

end

function ApiProperty:__mul()

end

function ApiProperty:__div()

end

function ApiProperty:__mod()

end

function ApiProperty:__pow()

end

function ApiProperty:__concat()

end

function ApiProperty:__eq()

end

function ApiProperty:__lt()

end

function ApiProperty:__le()

end

return ApiProperty