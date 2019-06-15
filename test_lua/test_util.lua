---
--- Created by slanska.
--- DateTime: 2017-12-25 10:38 AM
---

--[[
Set of utility functions to help with Flexilite testing
Also, sets Lua package path to allow loading all dependencies
These paths are needed to be configured for testing only, as
Flexilite library will bundle all dependencies via luajit bytecode and module
name registration
]]

--local mobdebug = require('mobdebug')
--mobdebug.start()

sqlite3 = require 'lsqlite3complete'
local class = require 'pl.class'
local stringx = require 'pl.stringx'
local path = require 'pl.path'

-- set lua paths
require 'test_paths'

-- For Lua 5.2 compatibility
unpack = table.unpack

local __dirname = path.abspath('..')

--- Read file
---@param file string
local function readAll(file)
    local f = io.open(file, "rb")
    local content = f:read("*all")
    f:close()
    return content
end

-- Flexi object
require 'index'

-- load sql scripts into Flexi variables
Flexi.DBSchemaSQL = readAll(path.join(__dirname, 'sql', 'dbschema.sql'))
Flexi.InitDefaultData = readAll(path.join(__dirname, 'sql', 'init_default_data.sql'))

---@param db sqlite3
---@return DBContext
local function initFlexiDatabase(db)
    local result = Flexi:newDBContext(db)
    db:exec "select flexi('configure')"
    return result
end

-- Creates and initializes Flexilite database in memory
---@return DBContext
local function openFlexiDatabaseInMem()
    local db, errMsg = sqlite3.open_memory()
    if not db then
        error(errMsg)
    end
    return initFlexiDatabase(db)
end

-- Creates and initializes Flexilite database using given file name
---@param fileName string
---@return DBContext
local function openFlexiDatabase(fileName)
    local db, errMsg = sqlite3.open(fileName)
    if not db then
        error(errMsg)
    end
    return initFlexiDatabase(db)
end

---@param DBContext DBContext
---@param fileName string
local function importData(DBContext, fileName)
    -- Insert data
    local started = os.clock()
    local dataDump = readAll(path.join(__dirname, fileName))
    local sql = "select flexi('import data', '" .. stringx.replace(dataDump, "'", "''") .. "');"
    DBContext:ExecAdhocSql(sql)
    -- TODO temp
    print(string.format('flexi_data - Elapsed %s sec', os.clock() - started))
end

---@param DBContext DBContext
local function importNorthwindData(DBContext)
    importData(DBContext, 'test/json/Northwind.db3.data.json')
end

---@param DBContext DBContext
---@param fileName string
local function createSchema(DBContext, fileName)
    local fullPath = path.join(__dirname, 'test', 'json', fileName)
    local content = readAll(fullPath)
    local sql = "select flexi('create schema', '" .. content .. "');"
    DBContext:ExecAdhocSql(sql)
    print('createSchema: ' .. fileName .. ' done')
end

---@param DBContext DBContext
local function createNorthwindSchema(DBContext)
    createSchema(DBContext, 'Northwind.db3.schema.json')
end

-- load sql scripts into Flexi variables
-- TODO use relative paths
Flexi.DBSchemaSQL = readAll(path.join(__dirname, 'sql', 'dbschema.sql'))
Flexi.InitDefaultData = readAll(path.join(__dirname, 'sql', 'init_default_data.sql'))

local function createChinookSchema(DBContext)
    createSchema(DBContext, 'Chinook.db.schema.json')
end

local function importChinookData(DBContext)
    importData(DBContext, 'test/json/Chinook.db.data.json')
end

---@class TestContext
---@field DBContexts table<string, DBContext[]> @comment Pool of DBContext for Northwind database
local TestContext = class()

function TestContext:_init()
    self.DBContexts = {}
end

---@param name string
---@return DBContext
function TestContext:getDBContext(name)
    local list = self.DBContexts[name]
    if list == nil then
        list = {}
    end

    ---@type DBContext
    local result

    if #list > 0 then
        result = list[1]
        table.remove(list, 1)
    else
        result = openFlexiDatabaseInMem()
        if name == 'Northwind' then
            createNorthwindSchema(result)
            importNorthwindData(result)
        elseif name == 'Chinook' then
            createChinookSchema(result)
            importChinookData(result)
        else
            error(string.format('Invalid DBContext name %s', name))
        end
    end

    -- TODO result:ExecAdhocSql('begin')
    return result
end

-- Returns DBContext for Northwind database in memory
-- Begins transaction
function TestContext:GetNorthwind()
    return self:getDBContext('Northwind')
end

---@param name string
---@param DBContext DBContext
---@param commit boolean
function TestContext:Release(name, DBContext, commit)
    assert(DBContext ~= nil)
    if commit then
        DBContext:ExecAdhocSql('commit')
    else
        DBContext:ExecAdhocSql('rollback')
    end
    table.insert(self.DBContexts[name] or {}, DBContext)
end

-- Returns DBContext for Chinook database in memory
-- Begins transaction
function TestContext:GetChinook()
    return self:getDBContext('Chinook')
end

return {
    readAll = readAll,
    openFlexiDatabaseInMem = openFlexiDatabaseInMem,
    openFlexiDatabase = openFlexiDatabase,
    importNorthwindData = importNorthwindData,
    createNorthwindSchema = createNorthwindSchema,
    createChinookSchema = createChinookSchema,
    importChinookData = importChinookData,
    TestContext = TestContext,
}
