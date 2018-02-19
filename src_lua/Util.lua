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

-- Converts string in JavaScript datetime format to number in Julian calendar
-- Source: https://forums.coronalabs.com/topic/29019-convert-string-to-date/
---@param str string
---@return number
local function parseDatTimeToJulian(str)
    local yr, mo, day = str:match('^%s*(%d+)%-(%d+)%-(%d+)')
    local hr, min, sec = str:match('[T,%s](%d+)([%:%d+])?[%:(%d+)]?')

    local pattern = "^(%d+)%-(%d+)%-(%d+)[T,%s*]?[(%d+)%:(%d+)]?[%:(%d+)]?([%+,%-])?[(%d+)%:(%d+)]?$"
    local yr, mo, day, hr, min, sec, xoffset, xoffsethour, xoffsetmin = str:match(pattern)

    print('parseDatTimeToJulian', pretty.dump({ str = str, year = yr, month = mo, day = day, hour = hr,
                                                min = min, sec = sec, xoffseet = xoffset, xoffsethour = xoffsethour,
                                                xoffsetmin = xoffsetmin }))

    local offset = (xoffsethour or 0) * 60 + (xoffsetmin or 0)
    if xoffset == "-" then
        offset = offset * -1
    end
    local result = JulianDate.dateToJulian('', yr, mo, day, hr, min, sec)
    result = result + (offset / (60 * 24))
    return result
end

---@param dt DateTimeInfo
---@return string
local function stringifyDateTimeInfo(dt)
    local result = string.format('%.4d-%.2d-%.2dT%.2d:%.2d:%.2dZ',
                                 dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second)
    return result
end

local function stringifyJulianToDateTime(num)
    local dt = JulianDate.julianToDate(num)
    return stringifyDateTimeInfo(dt)
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
    stringifyDateTimeInfo = stringifyDateTimeInfo
}