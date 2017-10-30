--
-- Created by IntelliJ IDEA.
-- User: slanska
-- Date: 2017-10-29
-- Time: 10:32 PM
-- To change this template use File | Settings | File Templates.
--


--local box = require('box')

--print('before mobdebug')
require("mobdebug").listen()

function sleep (a)
    local sec = tonumber(os.clock() + a);
    while (os.clock() < sec) do
    end
end

sleep(5)
--print('Awaiken')

local aaa = {ddd = "bbb"}

--box.cfg {
--    listen = 3301,
--    background = true,
--    log = '1.log',
--    pid_file = '1.pid'
--}

print(aaa.ddd)


