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

---@class ApiValue
local ApiValue = class()

function ApiValue:_init()

end

---@class ApiProperty
local ApiProperty = class(ApiValue)

-- Hide metadata
function ApiValue:__metadata()
    return nil
end

function ApiValue:__index(key)

end

function ApiValue:__newindex(key, value)

end

function ApiValue:__tostring()

end

function ApiValue:__len()

end

function ApiValue:__unm()

end

function ApiValue:__add()

end

function ApiValue:__sub()

end

function ApiValue:__mul()

end

function ApiValue:__div()

end

function ApiValue:__mod()

end

function ApiValue:__pow()

end

function ApiValue:__concat()

end

function ApiProperty:__eq()

end

function ApiValue:__lt()

end

function ApiValue:__le()
end

-- Constructor
---@param propDef PropertyDef
---@param object ApiObject
function ApiProperty:_init(propDef, object)
    super:init()
    self.propDef = propDef
    self.object = object
end

---@param prop ApiProperty
local function ApiPropertyProxy(prop)

    local self = setmetatable({}, {
        __index = function(idx)
            return
        end,

        __newindex = function(idx, val)
        end,

        __metatable = function()
            return nil
        end
    })

    return self
end

return ApiProperty