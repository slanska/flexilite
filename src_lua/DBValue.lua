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

-- Direct mapping to [.ref-values] row
---@class DBValueCtorParams
---@field Value any
---@field ctlv number
---@field MetaData table | string

---@class DBValue
---@field Value any @comment Raw cell value (as it is stored in [.ref-values])
---@field ctlv number
---@field MetaData table|nil
local DBValue = class()

---@class DBValueBoxed
---@field ValueGetter function | DBValue
---@field Prop DBProperty
---@field Idx number
local DBValueBoxed = class()

---@param valueGetter function | DBValue
---@param prop DBProperty
---@param idx number
function DBValueBoxed:_init(valueGetter, prop, idx)
    rawset(self, 'ValueGetter', assert(valueGetter))
    rawset(self, 'Prop', assert(prop))
    rawset(self, 'Idx', assert(idx))
    rawset(self, 'ValueGetter', valueGetter)
end

function DBValueBoxed:__metatable()
    return nil
end

function DBValueBoxed:__tostring()
    local result = self:ValueGetter()
    return tostring(result)
end

function DBValueBoxed:__len(val)
    return #self:ValueGetter()
end

function DBValueBoxed:__unm()
    return -self:ValueGetter()
end

function DBValueBoxed:__add(val)
    if type(val) == 'table' then
        self, val = val, self
    end

    return tonumber(self:ValueGetter()) + val
end

function DBValueBoxed:__sub(val)
    if type(val) == 'table' then
        self, val = val, self
        return val - self:ValueGetter()
    end

    return self:ValueGetter() - val
end

function DBValueBoxed:__mul(val)
    return tonumber(self:ValueGetter()) * val
end

function DBValueBoxed:__div(val)
    --if type(val) == 'table' then
    --    self, val = val, self
    --end

    local result = self:ValueGetter() / val

    return result
end

function DBValueBoxed:__mod(val)
    --if type(val) == 'table' then
    --    self, val = val, self
    --end

    local result = tonumber(self:ValueGetter()) % val

    return result
end

function DBValueBoxed:__pow(val)
    return self:ValueGetter() ^ val
end

function DBValueBoxed:__concat(val)
    return self:ValueGetter() .. val
end

function DBValueBoxed:__eq(val)
    if type(val) == 'table' then
        self, val = val, self
    end

    return self:ValueGetter() == val
end

function DBValueBoxed:__lt(val)
    if type(val) == 'table' then
        self, val = val, self
        return self:ValueGetter() > val
    end
    return self:ValueGetter() < val
end

function DBValueBoxed:__le(val)
    if type(val) == 'table' then
        self, val = val, self
        return self:ValueGetter() >= val
    end
    return self:ValueGetter() <= val
end

-- constructor
---@param row DBValueCtorParams
function DBValue:_init(row)
    if row then
        self.Value = row.Value
        self.ctlv = row.ctlv or 0
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
        self.boxed = DBValueBoxed(DBValue.valueGetter, self, propIndex)
    end

    return self.boxed
end

function DBValue:valueGetter()
    return self.Value
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

-- Singleton constant Null DBValue. All operations with Null value result in null
local NullDBValue

local function NullFunc()
    return NullDBValue
end

NullDBValue = setmetatable({}, {
    __index = NullFunc,
    __newindex = function()
        error('Not assignable null value')
    end,
    __metatable = nil,
    __add = NullFunc,
    __sub = NullFunc,
    __mul = NullFunc,
    __div = NullFunc,
    __pow = NullFunc,
    __concat = NullFunc,
    __len = NullFunc,
    __tostring = function()
        return '<null>'
    end,
    __unm = NullFunc,
    __eq = NullFunc,
    __lt = NullFunc,
    __le = NullFunc,
    __mod = NullFunc,
})

DBValue.BoxedClass = DBValueBoxed
DBValue.Null = NullDBValue

return DBValue
