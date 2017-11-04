---
--- Created by slanska.
--- DateTime: 2017-11-01 10:29 PM
---

--[[
This file is used as an entry point for testing Flexilite library
]]

require 'socket'
require('mobdebug').start()
require 'cjson'
require('index')
require('io')

local sqlite = require 'lsqlite3complete'
local db = sqlite.open_memory()
--db:load_extension('/Users/ruslanskorynin/Documents/Github/slanska/flexilite/bin/libFlexilite')

Flexi:newDBContext(db)

local function readAll(file)
    local f = io.open(file, "rb")
    local content = f:read("*all")
    f:close()
    return content
end

-- load sql scripts into Flexi variables
Flexi.DBSchemaSQL = readAll('/Users/ruslanskorynin/Documents/Github/slanska/flexilite/sql/dbschema.sql')
Flexi.InitDefaultData = readAll('/Users/ruslanskorynin/Documents/Github/slanska/flexilite/sql/init_default_data.sql')

local ok, errorMessage = pcall(function()

    for row in db:rows [=[
    select flexi('create class', 'Orders', '{"ref": 123}', 1);]=] do
        print(row[1])
    end

    db:exec "select flexi('configure');"
end)

if not ok then
    print(errorMessage)
end


