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
-- TODO return function to use DBProperty and propIndex
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

            __add = self.boxed_add,
            __sub = self.boxed_sub,
            __mul = self.boxed_mul,
            __div = self.boxed_div,
            __pow = self.boxed_pow,
            __concat = self.boxed_concat,
            __len = self.boxed_len,
            __tostring = self.boxed_tostring,
            __unm = self.boxed_unm,
            __eq = self.boxed_eq,
            __lt = self.boxed_lt,
            __le = self.boxed_le,
            __mod = self.boxed_mod,
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

function DBValue:boxed_tostring(v)

end

function DBValue:boxed_len(v)

end

function DBValue:boxed_unm(v)

end

function DBValue:boxed_add(v1, v2)

end

function DBValue:boxed_sub(v1, v2)

end

function DBValue:boxed_mul(v1, v2)

end

function DBValue:boxed_div(v1, v2)

end

function DBValue:boxed_mod(v1, v2)

end

function DBValue:boxed_pow(v1, v2)

end

function DBValue:boxed_concat(v1, v2)

end

function DBValue:boxed_eq(v1, v2)

end

function DBValue:boxed_lt(v1, v2)

end

function DBValue:boxed_le(v1, v2)
end

return DBValue
