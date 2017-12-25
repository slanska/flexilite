---
--- Created by slanska.
--- DateTime: 2017-12-24 8:11 PM
---

-- Miscellaneous helper functions

--[[
Lua can operate on integers of max 52 bit, without precision loss.
However, bit operations are limited to 32 bit integers only (to be exact, to 31 bit masks). To overcome this limit, this module has few
helper functions, which can operate on 52 bit values by 26 bit chunks
]]

local math = require 'math'
local bits = type(jit) == 'table' and require('bit') or require('bit32')

-- Max value for 26 bit integer
local MAX26 = 0x3FFFFFF -- 67108863

---@param value number
local function divide(value)
    return math.floor(value / MAX26), value % MAX26
end

---@param base number
---@param value number
local function BOr64(base, value)
    local d, r = divide(base)
    local d2, r2 = divide(value)
    local result = bits.bor(d, d2) * MAX26 + bits.bor(r, r2)
    return result
end

---@param base number
---@param value number
local function BAnd64(base, value)
    local d, r = divide(base)
    local d2, r2 = divide(value)
    local result = bits.band(d, d2) * MAX26 + bits.band(r, r2)
    return result
end

---@param base number
---@param mask number
---@param value number
local function BSet64(base, mask, value)
    local result = BOr64(BAnd64(base, mask), value)
    return result
end

---@param base number
local function BNot64(base)
    local d, r = divide(base)
    local result = bits.bnot(d) * MAX26 + bots.bnot(r)
    return result
end

---@param base number
---@param shift number
local function BLShift64(base, shift)
    local result = base * (2 ^ shift)
    return result
end

return {
    BOr64 = BOr64,
    BAnd64 = BAnd64,
    BSet64 = BSet64,
    BNot64 = BNot64,
    BLShift64 = BLShift64
}