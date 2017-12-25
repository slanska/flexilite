---
--- Created by slanska.
--- DateTime: 2017-12-25 10:37 AM
---

--[[Test bit 52 operations]]
require 'util'
local Util64 = require 'Util'

-- Just 52 bit value
local A53 = 0x925FE988710BA --2575050201305274
local NotA53 = -2575050201305275
local B53 = 0x000FE988000BA --2575050201305274
local Max53 = 0x1FFFFFFFFFFFFF ---9007199254740991

describe('Bit52 tests', function()

    it('BOr64', function()
        local v = Util64.BOr64(A53, B53)
        --2575050201305274
        assert.are.equal(2575050201305274, v)
    end)

    it('BAnd64', function()
        local v = Util64.BAnd64(A53, B53)
        assert.are.equal(1093480218810, v)
    end)

    it('BNot64', function()
        local v = Util64.BNot64(A53)
        assert.are.equal(v, NotA53)
    end)

    it('BSet64', function()

    end)

    it('BLShift64', function()
        assert.are.equal(Util64.BLShift64( 0x8710BA, 30), 9504378226475008)
    end)

end)