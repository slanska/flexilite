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

local ticksPerDay = 24 * 60 * 60 * 1000000

-- Converts string in JavaScript datetime format to number in Julian calendar
-- Source: https://forums.coronalabs.com/topic/29019-convert-string-to-date/
---@param str string
---@return number
local function parseDateTimeToJulian(str)
    ---@type DateObject
    local dateObj = date(str)
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

-- Case-insensitive dictionary. Used for classes and class properties.
-- Supports string and integer keys only.
---@class DictCI

---@param values table | nil
local function DictCI(values)
    local items = {}

    local result = setmetatable({}, {
        __index = function(tbl, key)
            if type(key) == 'string' then
                key = string.lower(key)
            end

            return rawget(items, key)
        end,

        __newindex = function(tbl, key, value)
            if type(key) == 'string' then
                key = string.lower(key)
            end
            return rawset(items, key, value)
        end,

        __pairs = function(tbl)
            return pairs(items)
        end,

        __ipairs = function(tbl)
            return ipairs(items)
        end,

        --__metatable = nil,
    })

    if values then
        for k, v in pairs(values) do
            result[k] = v
        end
    end

    return result
end

--local DictCI = class()
--
-----@param values table | nil
--function DictCI:_init(values)
--
--    local items = {}
--
--    self.__pairs = function()
--        return pairs(items)
--    end
--
--    self.__ipairs = function()
--        return ipairs(items)
--    end
--
--    self.__index = function(key)
--        if type(key) == 'string' then
--            key = string.lower(key)
--        end
--
--        return rawget(items, key)
--    end
--
--    -- Set __newindex at last step
--    self.__newindex = function(key, value)
--        if type(key) == 'string' then
--            key = string.lower(key)
--        end
--        return rawset(items, key, value)
--    end
--
--    if values then
--        for k, v in pairs(values) do
--            self[k] = v
--        end
--    end
--end

--- Normalizes SQL table or column name by removing spaces, [] and ``
---@param n string @comment class or property name
---@return string
local function normalizeSqlName(n)
    local _, _, result = string.find(n, '^%s*%[(%w+)%]%s*$')

    if result == nil then
        _, _, result = string.find(n, '^%s*%`(%w+)%`%s*$')
    end

    -- Normal string
    if result == nil then
        _, _, result = string.find(n, '^%s*(%w+)%s*$')
    end

    return result
end

local export = {
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

    parseDateTimeToJulian = parseDateTimeToJulian,
    stringifyJulianToDateTime = stringifyJulianToDateTime,
    stringifyDateTimeInfo = stringifyDateTimeInfo,
    DictCI = DictCI,
    normalizeSqlName = normalizeSqlName,
}

return export
