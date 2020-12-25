---
--- Created by slanska.
--- DateTime: 2017-11-04 12:14 PM
---

local path = require 'pl.path'
local test_util = require 'util'
package.path = path.abspath(path.relpath('../src_lua')) .. '/?.lua;' .. package.path

require 'socket'
local json = cjson or require 'cjson'

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
Flexi.DBSchemaSQL = readAll(path.abspath(path.relpath('../sql/dbschema.sql')))
Flexi.InitDefaultData = readAll(path.abspath(path.relpath('../sql/init_default_data.sql')))

-- Tests for class creation

db = sqlite.open_memory()

local sql = "select flexi('configure')"
db:exec(sql)

Flexi:newDBContext(db)
-- TODO temp
local content = readAll(path.abspath(path.relpath('../test/json/Employees.schema.json')))
sql = "select flexi('create class', 'Employees', '" .. content .. "', 0);"
for row in db:rows(sql) do
    print(row[1])
end
db:close()

describe('Create class', function()

    local db
    local DBContext

    setup(function()
        -- TODO set search paths
        -- TODO use persistent file
        db = sqlite.open_memory()
        DBContext = Flexi:newDBContext(db)
    end)

    it('Create Employees table', function()
        -- TODO temp
        local content = readAll(path.abspath(path.relpath('../test/json/Employees.schema.json')))
        local sql = "select flexi('create class', 'Employees', '" .. content .. "', 0);"
        for row in db:rows(sql) do
            print(row[1])
        end
    end)

    pending('should create Regions', function()
        --assert.truthy("Yup.")
    end)

    pending('should create all Northwind classes', function()
    end)

    pending('should create unresolved class', function()

    end)

    pending('should create class with simple enum def', function()

    end)

    pending('should create class with named enum def', function()

    end)

    pending('should create class with existing class def', function()

    end)

    pending('should create class with enum def with auto assigned ID ', function()

    end)

    pending('should create class and resolve other class', function()

    end)

    pending('should fail on class with invalid definition', function()

    end)

    pending('should create mixin class', function()

    end)

    pending('should fail on invalid property definition', function()

    end)

    pending('create re-view with no from_UDID', function()
    end)

    pending('create re-view with no to_UDID', function()
    end)

    pending('create re-view with no both from_UDID and to_UDID', function()
    end)

    pending('create re-view with both from_UDID and to_UDID', function()
    end)

    teardown(function()
        db:close()
    end)

end)
