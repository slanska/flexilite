---
--- Created by slanska
--- DateTime: 2017-11-18 4:56 PM
---

--[[
Purpose of this function is to handle bundled C libraries in 'require'-like manner
]]
---@param moduleName string
local function _require()

    local old_require = _G.require

    local function r(moduleName)
        if moduleName == 'lfs' then
            return _G.lfs or old_require 'lfs'
        elseif moduleName == 'cjson' then
            return _G.cjson or old_require 'cjson'
        else
            return old_require(moduleName)
        end
    end

    return r
end

_G.require = _require()

local path = require 'pl.path'

-- set lua path
package.path =
path.abspath(path.relpath('../lib/lua-prettycjson/lib/resty/?.lua')) .. ';' ..
        path.abspath(path.relpath('../src_lua/?.lua')) .. ';' ..
        package.path

local sqlite3 = require 'lsqlite3complete'
local SQLiteSchemaParser = require 'sqliteSchemaParser'
local os = require 'os'
local lapp = require 'pl.lapp'
local DumpDatabase = require('dumpDatabase')
local ansicolors = require 'ansicolors'

local prettyJson = require "prettycjson"

---@class CLIArgs
---@field database string
---@field output string
---@field data string
---@field output string
---@field compactJson boolean
---@field config file
---@field table string
---@field query string

-- Checks presence of database path argument and ensures it is stored as absolute path
---@param cli_args CLIArgs
---@param argName string
local function EnsureAbsPathArg(cli_args, argName)
    if cli_args[argName] and not path.isabs(cli_args[argName]) then
        cli_args[argName] = path.abspath(path.relpath(cli_args[argName]))
    end
end

-- Generates schema for entire native SQLite database and saves it to the JSON file
---@param cli_args table
local function generateSchema(cli_args)
    EnsureAbsPathArg(cli_args, 'database')

    local db, errMsg = sqlite3.open(cli_args.database)
    if not db then
        error(errMsg)
    end

    local sqliteParser = SQLiteSchemaParser(db)
    local schema = sqliteParser:ParseSchema(cli_args.output)
    local schemaJson = prettyJson(schema)

    -- Save JSON to file or print to console
    if cli_args.output == nil or cli_args.output == '' then
        io.stdout:write(schemaJson)
    else
        EnsureAbsPathArg(cli_args, 'output')
        local f = io.open(cli_args.output, 'w')
        f:write(schemaJson)
        f:close()
    end

    -- Print warnings and other messages
    if sqliteParser.results then
        for i, item in ipairs(sqliteParser.results) do
            print(string.format("%s: [%s] %s", item.tableName, item.type, item.message))
        end
    end

    print(ansicolors(string.format('\n%%{cyan}Generated schema has been saved in %%{white}%s %%{reset}',
            cli_args.output)))
end

local function queryDatabase(args, options)

end

--- Loads data from JSON file
---@param cli_args CLIArgs
local function loadData(cli_args)
    EnsureAbsPathArg(cli_args, 'database')
    --cli_args.database


end

--- Configures database to be Flexilite ready (equivalent of flexi('config'))
local function configDatabase()

end

lapp.slack = true
local cli_args = lapp [[
Flexilite Shell Utility
<command> (string)  'schema' | 'load' | 'query' | 'help' | 'config' | 'dump'
<database> (string)  Path to SQLite database file
    -t, --table (string default '')  Name of specific SQLite table to process
    -o, --output (string default '')  Output file path
    -c, --config (file-in default '')  Path to config file
    -q, --query (string default '')  Path to query file
    -d, --data (string default '') Path to JSON file with data to load
    -cj, --compactJson (boolean default false)  If set, output JSON will be in compact (minified) form
]]

-- Dumps entire native SQLite database into single JSON file, ready for INSERT INTO flexi_data (Data) values (:DataInJSON)
-- or select flexi('load', null, :DataInJSON)
local function doDumpDatabase(cli_args)
    EnsureAbsPathArg(cli_args, 'database')
    EnsureAbsPathArg(cli_args, 'output')
    DumpDatabase(cli_args.database, cli_args.output, cli_args.table, cli_args.compactJson)
end

local commandMap = {
    ['schema'] = generateSchema,
    ['load'] = loadData,
    ['query'] = queryDatabase,
    ['config'] = configDatabase,
    ['dump'] = doDumpDatabase,
}

local ff = commandMap[cli_args.command]
if not ff then
    print("Unknown command %s", cli_args.command)
    os.exit()
end

local errorMsg = ''
local ok = xpcall(
        function()
            local result = ff(cli_args)
            return result
        end,
        function(error)
            errorMsg = tostring(error)
            print(debug.traceback(tostring(error)))
        end)

if not ok then
    error(errorMsg)
end

-- TODO process result?
