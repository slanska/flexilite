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

local mobdebug = require('mobdebug')
--mobdebug.start()

sqlite3 = require 'lsqlite3complete'

local stringx = require 'pl.stringx'
local path = require 'pl.path'

-- set lua paths
local paths = {
    '../lib/lua-prettycjson/lib/resty/?.lua',
    '../src_lua/?.lua',
    '../lib/lua-sandbox/?.lua',
    '../lib/lua-schema/?.lua',
    '../lib/lua-date/?.lua',
    '../lib/lua-metalua/?.lua',
    '../lib/lua-metalua/compiler/?.lua',
    '../lib/lua-metalua/compiler/bytecode/?.lua',
    '../lib/lua-metalua/compiler/parser/?.lua',
    '../lib/lua-metalua/extension/?.lua',
    '../lib/lua-metalua/treequery/?.lua',
    '../lib/lua-sandbox/?.lua',
}
for _, pp in ipairs(paths) do
    package.path = path.abspath(path.relpath(pp)) .. ';' .. package.path
end

-- For Lua 5.2 compatibility
unpack = table.unpack

local DBContext = require 'DBContext'

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

---@return DBContext
local function openFlexiDatabaseInMem()
    local db, errMsg = sqlite3.open_memory()
    if not db then
        error(errMsg)
    end
    return initFlexiDatabase(db)
end

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
local function importNorthwindData(DBContext)
    -- Insert data
    local started = os.clock()
    local dataDump = readAll(path.join(__dirname, 'test/json/Northwind.db3.data.json'))
    local sql = "select flexi('import data', '" .. stringx.replace(dataDump, "'", "''") .. "');"
    DBContext:ExecAdhocSql(sql)
    -- TODO temp
    print(string.format('flexi_data - Elapsed %s sec', os.clock() - started))

end

---@param DBContext DBContext
local function createNorthwindSchema(DBContext)
    local content = readAll(path.join(__dirname, 'test', 'json', 'Northwind.db3.schema.json'))
    local sql = "select flexi('create schema', '" .. content .. "');"
    DBContext:ExecAdhocSql(sql)
    print('createNorthwindSchema: done')
end

-- load sql scripts into Flexi variables
-- TODO use relative paths
Flexi.DBSchemaSQL = readAll(path.join(__dirname, 'sql', 'dbschema.sql'))
Flexi.InitDefaultData = readAll(path.join(__dirname, 'sql', 'init_default_data.sql'))

return {
    readAll = readAll,
    openFlexiDatabaseInMem = openFlexiDatabaseInMem,
    openFlexiDatabase = openFlexiDatabase,
    importNorthwindData = importNorthwindData,
    createNorthwindSchema = createNorthwindSchema,
}
