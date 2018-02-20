---
--- Created by slanska.
--- DateTime: 2017-11-01 10:29 PM
---

--[[
This file is used as an entry point for testing Flexilite library
]]
local mobdebug = require( "mobdebug" )
mobdebug.start()

--ProFi = require 'ProFi'

if jit then
    jit.on()
end

-- Source: https://gist.github.com/Tieske/b1654b27fa422afb63eb

--[[== START ============= temporary debug code ==============================--
-- on the line above, reduce the initial 3 dashes to 2 dashes to disable this
-- whole block when done debugging.
-- Insert this entire block at the start of your module.

-- with Lua 5.1 patch global xpcall to take function args (standard in 5.2+)
if _VERSION == "Lua 5.1" then
    local xp = xpcall
    xpcall = function(f, err, ...)
        local a = { n = select("#", ...), ... }
        return xp(function(...)
            return f(unpack(a, 1, a.n))
        end, err)
    end
end

-- error handler to attach stacktrack to error message
local ehandler = function(err)
    return debug.traceback(tostring(err))
end

-- patch global pcall to attach stacktrace to the error.
pcall = function(fn, ...)
    return xpcall(fn, ehandler, ...)
end
--==== END =============== temporary debug code ============================]]--

require 'cjson'
local path = require 'pl.path'

package.path = path.abspath(path.relpath('../lib/lua-date/?.lua'))
        .. ';' .. package.path

--local date = require 'date'
--local pretty = require 'pl.pretty'

local __dirname = path.abspath('..')

require('io')
require('index')
local sqlite = require 'lsqlite3complete'
sqlite3 = sqlite
local DBContext = require 'DBContext'
local stringx = require 'pl.stringx'

--- Read file
---@param file string
local function readAll(file)
    local f = io.open(file, "rb")
    local content = f:read("*all")
    f:close()
    return content
end

local ok, error = xpcall(function()

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
    db = sqlite.open_memory()

    DBContext = Flexi:newDBContext(db)

    local sql = "select flexi('configure')"
    db:exec(sql)

    local content = readAll(path.join(__dirname, 'test', 'json', 'Employees.schema.json'))
    --sql = "select flexi('create class', 'Employees', '" .. content .. "', 0);"
    --for row in db:rows(sql) do
    --    print(row[1])
    --end

    -- Create Northwind schema
    content = readAll(path.join(__dirname, 'test', 'json', 'Northwind.db3.schema.json'))
    sql = "select flexi('create schema', '" .. content .. "');"
    for row in db:rows(sql) do
        print(row[1])
    end

    --ProFi:start()

    -- Insert data
    local started = os.clock()
    --   local dataDump = readAll(path.join(__dirname, 'test/json/Northwind_Regions.db3.data.json' ))
    local dataDump = readAll(path.join(__dirname, 'test/json/Northwind.db3.data.json' ))
    --local dataDump = readAll(path.join(__dirname, 'test/json/Northwind.db3.trimmed.data.json' ))
    sql = "select flexi('import data', '" .. stringx.replace(dataDump, "'", "''") .. "');"
    for row in db:rows(sql) do
        print(row[1])
    end
    print(string.format('flexi_data - Elapsed %s sec', os.clock() - started))

    local dbPath2 = path.abspath(path.relpath('./Flexilite2.db'))
    local db2 = sqlite3.open_memory()
    --local db2 = sqlite3.open(dbPath2)
    content = readAll(path.abspath(path.relpath( './flexilite.data.sql')))
    started = os.clock()
    db2:exec(content)
    print(string.format('Direct load - Elapsed %s sec', os.clock() - started))
    db2:close()

    db:close()
end,

                         function(error)
                             print(string.format("%s, %s", ok, error))
                             --print(debug.stacktrace())
                             print(debug.traceback(tostring(error)))
                         end)


--ProFi:stop()
--ProFi:writeReport(path.abspath(path.relpath( './ProfileReport.txt')))
