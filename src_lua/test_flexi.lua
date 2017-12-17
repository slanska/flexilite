---
--- Created by slanska.
--- DateTime: 2017-11-01 10:29 PM
---

--[[
This file is used as an entry point for testing Flexilite library
]]

require 'cjson'
local path = require 'pl.path'

local __dirname = path.abspath('..')

local DBContext = require 'DBContext'
require('io')
require('index')
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
Flexi.DBSchemaSQL = readAll(path.join(__dirname, 'sql', 'dbschema.sql'))
Flexi.InitDefaultData = readAll(path.join(__dirname, 'sql', 'init_default_data.sql'))

-- Tests for class creation
local dbPath = path.abspath(path.relpath('../data/Flexilite.db'))
print('SQLite database: ', dbPath)
db, errMsg = sqlite.open(dbPath)
if not db then
    error(errMsg)
end
--db = sqlite.open_memory()
DBContext = Flexi:newDBContext(db)

local sql = "select flexi('configure')"
db:exec(sql)

local content = readAll(path.join(__dirname, 'test', 'json', 'Employees.schema.json'))
--sql = "select flexi('create class', 'Employees', '" .. content .. "', 0);"
--for row in db:rows(sql) do
--    print(row[1])
--end

content = readAll(path.join(__dirname, 'test', 'json', 'Northwind.db3.schema.json'))
sql = "select flexi('create schema', '" .. content .. "');"
for row in db:rows(sql) do
    print(row[1])
end

db:close()

