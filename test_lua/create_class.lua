---
--- Created by slanska.
--- DateTime: 2017-11-04 12:14 PM
---

package.path = '../src_lua/?.lua;' .. package.path

require 'socket'
require('mobdebug').start()
require 'cjson'

--local DBContext = require '/Users/ruslanskorynin/Documents/Github/slanska/flexilite/src_lua/DBContext'
--local lfs = require 'lfs'
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
Flexi.DBSchemaSQL = readAll('/Users/ruslanskorynin/Documents/Github/slanska/flexilite/sql/dbschema.sql')
Flexi.InitDefaultData = readAll('/Users/ruslanskorynin/Documents/Github/slanska/flexilite/sql/init_default_data.sql')

-- Tests for class creation

db = sqlite.open_memory()

local sql = "select flexi('configure')"
db:exec(sql)

Flexi:newDBContext(db)
-- TODO temp
local content = readAll('/Users/ruslanskorynin/Documents/Github/slanska/flexilite/test/json/Employees.schema.json')
sql = "select flexi('create class', 'Employees', '" .. content .. "', 0);"
for row in db:rows(sql) do
    print(row[1])
end
db:close()

--[[
describe('Create class', function()

    local db
    local DBContext

    setup(function()
        -- TODO use persistent file
        db = sqlite.open_memory()
        DBContext = Flexi:newDBContext(db)
    end)

    it('Create Employees table', function()
        -- TODO temp
        local content = readAll('/Users/ruslanskorynin/Documents/Github/slanska/flexilite/test/json/Employees.schema.json')
        local sql = "select flexi('create class', 'Employees', '" .. content .. "', 0);"
        for row in db:rows(sql) do
            print(row[1])
        end
    end)

    it('Create Regions table', function()
        --assert.truthy("Yup.")
    end)

    teardown(function()
        db:close()
    end)

end)
]]