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

sqlite3 = require 'lsqlite3complete'
local class = require 'pl.class'
local stringx = require 'pl.stringx'
local path = require 'pl.path'

-- set lua paths
local paths = {
    '../lib/lua-prettycjson/lib/resty/?.lua',
    '../src_lua/?.lua',
    '../lib/lua-sandbox/?.lua',
    '../lib/lua-schema/?.lua',
    '../lib/lua-date/src/?.lua',
    '../lib/lua-metalua/?.lua',
    '../lib/lua-metalua/compiler/?.lua',
    '../lib/lua-metalua/compiler/bytecode/?.lua',
    '../lib/lua-metalua/compiler/parser/?.lua',
    '../lib/lua-metalua/extension/?.lua',
    '../lib/lua-metalua/treequery/?.lua',
    '../lib/lua-sandbox/?.lua',
    '../lib/debugger-lua/?.lua',
    '../lib/md5.lua/?.lua',
    '../?.lua',
}

for _, pp in ipairs(paths) do
    package.path = path.abspath(path.relpath(pp)) .. ';' .. package.path
end

local dbg = require('debugger')
dbg.auto_where = 2

local DBContext = require 'DBContext'

-- For Lua 5.2 compatibility
unpack = table.unpack

local __dirname = path.abspath('..')

local module = {
}

--- Read file
---@param file string
function module.readAll(file)
    local f = io.open(file, "rb")
    local content = f:read("*all")
    f:close()
    return content
end

-- Flexi object
--require 'all_tests'

Flexi = {}
-- load sql scripts into Flexi variables
Flexi.DBSchemaSQL = module.readAll(path.join(__dirname, 'sql', 'dbschema.sql'))
Flexi.InitDefaultData = module.readAll(path.join(__dirname, 'sql', 'init_default_data.sql'))

---@param db userdata @comment sqlite3
---@return DBContext
local function initFlexiDatabase(db)
    local result = DBContext(db)
    db:exec "select flexi('configure')"
    return result
end

-- Creates and initializes Flexilite database in memory
---@return DBContext
function module.openFlexiDatabaseInMem()
    local db, errMsg = sqlite3.open_memory()
    if not db then
        error(errMsg)
    end
    return initFlexiDatabase(db)
end

-- Creates and initializes Flexilite database using given file name
---@param fileName string
---@return DBContext
function module.openFlexiDatabase(fileName)
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

    local dataDump = module.readAll(path.join(__dirname, fileName))
    local sql = "select flexi('import data', '" .. stringx.replace(dataDump, "'", "''") .. "');"

    DBContext:ExecAdhocSql(sql)

    print(string.format('flexi_data - Elapsed %s sec', os.clock() - started))
end

---@param DBContext DBContext
function module.importNorthwindData(DBContext)
    importData(DBContext, 'test/json/Northwind.db3.data.json')
end

---@param DBContext DBContext
---@param fileName string
local function createSchema(DBContext, fileName)
    local fullPath = path.join(__dirname, 'test', 'json', fileName)
    local content = module.readAll(fullPath)
    local sql = "select flexi('create schema', '" .. content .. "');"
    DBContext:ExecAdhocSql(sql)
    print('createSchema: ' .. fileName .. ' done')
end

---@param DBContext DBContext
function module.createNorthwindSchema(DBContext)
    createSchema(DBContext, 'Northwind.db3.schema.json')
end

function module.createChinookSchema(DBContext)
    createSchema(DBContext, 'Chinook.db.schema.json')
end

function module.importChinookData(DBContext)
    importData(DBContext, 'test/json/Chinook.db.data.json')
end

---@class TestContext
---@field DBContexts table<string, DBContext[]> @comment Pool of DBContext for Northwind database
module.TestContext = class()

function module.TestContext:_init()
    self.DBContexts = {}
end

---@param name string
---@return DBContext
function module.TestContext:getDBContext(name)
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
        result = module.openFlexiDatabaseInMem()
        if name == 'Northwind' then
            module.createNorthwindSchema(result)
            module.importNorthwindData(result)
        elseif name == 'Chinook' then
            module.createChinookSchema(result)
            module.importChinookData(result)
        else
            error(string.format('Invalid DBContext name %s', name))
        end
    end

    return result
end

-- Returns DBContext for Northwind database in memory
-- Begins transaction
function module.TestContext:GetNorthwind()
    return self:getDBContext('Northwind')
end

---@param name string
---@param DBContext DBContext
---@param commit boolean
function module.TestContext:Release(name, DBContext, commit)
    assert(DBContext ~= nil)
    if commit then
        DBContext:ExecAdhocSql('commit;')
    else
        DBContext:ExecAdhocSql('rollback;')
    end
    table.insert(self.DBContexts[name] or {}, DBContext)
end

-- Returns DBContext for Chinook database in memory
-- Begins transaction
function module.TestContext:GetChinook()
    return self:getDBContext('Chinook')
end

---@param dbFilePath string
function module.deleteDatabase(dbFilePath)
    os.remove()
end

return module
