---
--- Created by slanska.
--- DateTime: 2017-11-07 2:25 PM
---

require 'test_util'

local Util = require('Util')

--[[ Miscellaneous tests for utility classes ]]

--[[
SELECT julianday([value]) from json_each('["2017-12-01T11:30",' ||
                                       '"1970-01-01",' ||
                                       '"1499-12-30T14:50:34",' ||
                                       '"1970-05-06T10:39",' ||
                                       '"1946-12-30T22:40:02",' ||
                                       '"1946-12-30T22:40:03",' ||
                                       '"-1946-12-30T22:40:02",' ||
                                       '"-1946-12-30 22:40:03"]');


2458088.9791666665
2440587.5
2268922.118449074
2440712.94375
2432185.4444675925
2432185.4444791665
1010662.4444675926
1010662.4444791666

]]

describe('misc tests', function()

    describe('PropertyDef utility tests', function()

        pending('should use correct subclasses', function()

        end)

        pending('should convert from JulianDate', function()

        end)

        pending('should convert to JulianDate', function()

        end)

        pending('should match identifier name', function()

        end)

    end)

    describe('normalizeSqlName tests', function()

        local tests = {
            { name = '  [Abc] ', expected = 'Abc' },
            { name = '  `Abc` ', expected = 'Abc' },
            { name = '`Abc` ', expected = 'Abc' },
            { name = ' `Abc`', expected = 'Abc' },
            { name = '[Abc]', expected = 'Abc' },
            { name = '[Abc]  ', expected = 'Abc' },
            { name = ' Abc  ', expected = 'Abc' },
            { name = 'Abc  ', expected = 'Abc' },
            { name = '  Abc', expected = 'Abc' },
            { name = 'Abc', expected = 'Abc' },
            { name = '[123]', expected = '123' },
        }

        it(':', function()
            for _, tt in ipairs(tests) do
                local fact = Util.normalizeSqlName(tt.name)
                assert.are.equal(fact, tt.expected)
            end
        end)
    end)

    describe('DictCI', function()

        local DictCI = require('Util').DictCI

        it('should ignore case', function()
            local d = DictCI()
            local pp1 = {}
            d.products = pp1
            local pp2 = d.Products
            assert(pp1 == pp2)
        end)
    end)

end)
