---
--- Created by slanska.
--- DateTime: 2017-11-01 10:29 PM
---

--[[
This file is used as an entry point for testing Flexilite library
]]

--require('socket')
--require('mobdebug').start()

local sqlite = require('lsqlite3complete')
local db = sqlite.open_memory()
db:load_extension('/Users/ruslanskorynin/Documents/Github/slanska/flexilite/bin/libFlexilite')
