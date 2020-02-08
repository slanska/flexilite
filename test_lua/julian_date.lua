--[[
 Created by slanska on 2019-07-01.
]]
require 'test_util'
local jd = require('JulianDate')

-->>
--require('debugger').auto_where = 2

--describe('JulianDate', function()

local jdates = {}

--it('dateToJulian', function()
for _ = 1, 1000000, 1 do
    local y = math.random(0, 2020)
    local m = math.random(1, 12)
    local d = math.random(1, 28)
    local h = math.random(0, 23)
    local min = math.random(0, 59)
    local sec = math.random(0, 59)
    local jj = jd.dateToJulian('', y, m, d, h, min, sec)
    --table.insert(jdates, jj)
end
--end)

--it('julianToDate', function()
for i = 1, #jdates do
    local idx = math.random(1, #jdates)
    local jj = jdates[idx]
    jd.julianToDate(jj)
end
--end)

--end)
