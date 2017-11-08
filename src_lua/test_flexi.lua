---
--- Created by slanska.
--- DateTime: 2017-11-01 10:29 PM
---

--[[
This file is used as an entry point for testing Flexilite library
]]

require 'cjson'

require('socket')
require('mobdebug').start()

local DBContext = require 'DBContext'
--local lfs = require 'lfs'
require('io')
require('index')
--local sqlite = require 'lsqlite3'
local sqlite = require 'lsqlite3complete'

--- Read file
---@param file string
local function readAll(file)
    local f = io.open(file, "rb")
    local content = f:read("*all")
    f:close()
    return content
end

-- load sql scripts into Flexi variables
-- TODO use relative paths
Flexi.DBSchemaSQL = readAll('/Users/ruslanskorynin/Documents/Github/slanska/flexilite/sql/dbschema.sql')
Flexi.InitDefaultData = readAll('/Users/ruslanskorynin/Documents/Github/slanska/flexilite/sql/init_default_data.sql')

-- Tests for class creation

db = sqlite.open_memory()
DBContext = Flexi:newDBContext(db)

local sql = "select flexi('configure')"
db:exec(sql)

-- TODO temp
local content = readAll('/Users/ruslanskorynin/Documents/Github/slanska/flexilite/test/json/Employees.schema.json')
local sql = "select flexi('create class', 'Employees', '" .. content .. "', 0);"
for row in db:rows(sql) do
    print(row[1])
end
db:close()

