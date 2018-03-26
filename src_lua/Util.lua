---
--- Created by slanska.
--- DateTime: 2017-12-24 8:11 PM
---

-- Miscellaneous helper functions

--[[
Lua can operate on integers of max 53 bit, without precision loss.
However, bit operations are limited to 32 bit integers only (to be exact, to 31 bit masks). To overcome this limit, this module has few
helper functions, which can operate on 53 bit values by 27 bit chunks
]]

local math = require 'math'
local bits = type(jit) == 'table' and require('bit') or require('bit32')
local JulianDate = require 'JulianDate'
local pretty = require 'pl.pretty'

-- TODO Use Penlight Date module
local date = require 'date'

local class = require 'pl.class'

-- Max value for 26 bit integer
local MAX27 = 0x8000000 -- 134217728

---@param value number
local function divide(value)
    return math.floor(value / MAX27), value % MAX27
end

---@param base number
---@param value number
local function BOr64(base, value)
    local d, r = divide(base)
    local d2, r2 = divide(value)
    return bits.bor(d, d2) * MAX27 + bits.bor(r, r2)
end

---@param base number
---@param value number
local function BAnd64(base, value)
    local d, r = divide(base)
    local d2, r2 = divide(value)
    return bits.band(d, d2) * MAX27 + bits.band(r, r2)
end

---@param base number
---@param mask number
---@param value number
local function BSet64(base, mask, value)
    return BOr64(BAnd64(base, mask), value)
end

---@param base number
---@param shift number
local function BLShift64(base, shift)
    return base * (2 ^ shift)
end

---@param base number
---@param shift number
local function BRShift64(base, shift)
    return base / (2 ^ shift)
end

-----@param base number
local function BNot64(base)
    base = -base - 1
    return base
end

---@class DateObject
---@field daynum number @comment number of days since 0 AD
---@field dayfrc number @comment ticks (1 sec = 1 000 000 ticks)

-- Converts string in JavaScript datetime format to number in Julian calendar
-- Source: https://forums.coronalabs.com/topic/29019-convert-string-to-date/
---@param str string
---@return number
local function parseDatTimeToJulian(str)
    ---@type DateObject
    local dateObj = date(str)
    local ticksPerDay = 24 * 60 * 60 * 1000000
    local result = dateObj.daynum + 1721425.5 + dateObj.dayfrc / ticksPerDay
    return result
end

---@param dt DateTimeInfo
---@return string
local function stringifyDateTimeInfo(dt)
    -- TODO time zone
    local result = string.format('%.4d-%.2d-%.2dT%.2d:%.2d:%.2d',
                                 dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second)
    return result
end

local function stringifyJulianToDateTime(num)
    local dt = JulianDate.julianToDate(num)
    return stringifyDateTimeInfo(dt)
end

---@class DictCI
local DictCI = class()

---@param values table | nil
function DictCI:_init(values)
    if values then
        for k, v in pairs(values) do
            self[k] = v
        end
    end
end

function DictCI:__index(key)
    if type(key) == 'string' then
        return rawget(self, string.lower(key))
    end

    return rawget(self, key)
end

function DictCI:__newindex(key, value)
    if type(key) == 'string' then
        return rawset(self, string.lower(key), value)
    end

    return rawset(self, key, value)
end

return {
    -- Bit operations on 52-bit values
    -- (52 bit integer are natively supported by Lua's number)
    bit52 = {
        ---@type function
        bor = BOr64,
        band = BAnd64,
        set = BSet64,
        bnot = BNot64,
        lshift = BLShift64,
        rshift = BRShift64
    },

    parseDatTimeToJulian = parseDatTimeToJulian,
    stringifyJulianToDateTime = stringifyJulianToDateTime,
    stringifyDateTimeInfo = stringifyDateTimeInfo,
    DictCI = DictCI
}