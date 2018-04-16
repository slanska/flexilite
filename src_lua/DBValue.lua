---
--- Created by slanska.
--- DateTime: 2017-12-20 7:19 PM
---

--[[
Single value holder. Maps to row in [.ref-values] table (or A-P columns in .objects table).

DBValue has no knowledge on column mapping and operates solely as all data is stored in .ref-values only.
This is DBObject/*DBOV responsibility to handle column mapping.
Always operates as it would be .ref-value item. DBObject internally handles mapping to A..P columns
in .objects table

Access to object property value to be used in user's custom
functions and triggers.
Provides Boxed() value which implements all table metamethods to mimic functionality
of real property,
so that Order.ShipDate or Order.OrderLines[1] will look as real object
properties.

Uses AccessControl to check access rules

Has following fields:
Value
MetaData
ctlv

For the sake of memory saving and easier data consistency property ID/class, object and property index
are not fields of DBValue. Instead, DBProperty and propIndex are passed to all DBValue's functions as
first 2 parameters. Thus DBObject is accessed from DBProperty.DBObject, PropertyDef from DBProperty.PropDef
]]

local class = require 'pl.class'
local JSON = require 'cjson'
local bits = type(jit) == 'table' and require('bit') or require('bit32')
local Constants = require 'Constants'

---@class DBValueCtorParams
---@field Value any
---@field ctlv number
---@field MetaData table | string

---@class DBValue
---@field Value any
---@field ctlv number
---@field MetaData table|nil
local DBValue = class()

-- constructor
---@param row DBValueCtorParams
function DBValue:_init(row)
    if row then
        self.Value = row.Value
        self.ctlv = row.ctlv
        if type(row.MetaData) == 'string' then
            self.MetaData = JSON.decode(row.MetaData)
        else
            self.MetaData = row.MetaData
        end
    end
end

---@param DBProperty DBProperty
---@param propIndex number
function DBValue:Boxed(DBProperty, propIndex)
    if not self.boxed then
        self.boxed = setmetatable({}, {
            __metatable = nil,

        -- set value by index
            ---@param idx number
            ---@param val any
            __newindex = function(idx, val)

            end,

        -- get value by index
            ---@param idx number
            ---@return any
            __index = function(idx)

            end,

            __add = self.__add,
            __sub = self.__sub,
            __mul = self.__mul,
            __div = self.__div,
            __pow = self.__pow,
            __concat = self.__concat,
            __len = self.__len,
            __tostring = self.__tostring,
            __unm = self.__unm,
            __eq = self.__eq,
            __lt = self.__lt,
            __le = self.__le,
            __mod = self.__mod,
        })
    end

    return self.boxed
end

function DBValue:getVType()
    return bits.band(self.ctlv, Constants.CTLV_FLAGS.VTYPE_MASK)
end

---@param DBProperty DBProperty
---@param propIndex number
function DBValue:beforeSaveToDB(DBProperty, propIndex)

    -- Check if there is column mapping
    if DBProperty.PropDef.ColMap then
        DBProperty.DBObject:setMappedPropertyValue(DBProperty.PropDef, self.Value)
    end
end

---@param DBProperty DBProperty
---@param propIndex number
function DBValue:afterSaveToDB(DBProperty, propIndex)

end

function DBValue:__tostring(v)

end

function DBValue:__len(v)

end

function DBValue:__unm(v)

end

function DBValue:__add(v1, v2)

end

function DBValue:__sub(v1, v2)

end

function DBValue:__mul(v1, v2)

end

function DBValue:__div(v1, v2)

end

function DBValue:__mod(v1, v2)

end

function DBValue:__pow(v1, v2)

end

function DBValue:__concat(v1, v2)

end

function DBValue:__eq(v1, v2)

end

function DBValue:__lt(v1, v2)

end

function DBValue:__le(v1, v2)
end

return DBValue
