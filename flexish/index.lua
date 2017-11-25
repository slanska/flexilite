---
--- Created by slanska
--- DateTime: 2017-11-18 4:56 PM
---

local sqlite3 = require 'lsqlite3complete'
local argparse = require 'argparse'
local SQLiteSchemaParser = require 'sqliteSchemaParser'
local json = require 'cjson'
local os = require 'os'
local path = require 'pl.path'

---@param args table
---@param options table
local function generateSchema(cli_args)
    if not path.isabs( cli_args.database) then
        cli_args.database = path.abspath(path.relpath(cli_args.database))
    end

    local db, errMsg = sqlite3.open(cli_args.database)
    if not db then
        error(errMsg)
    end

    local sqliteParser = SQLiteSchemaParser:new(db)
    local schema = sqliteParser:parseSchema()
    local out = json.encode(schema)
    return out
end

local function queryDatabase(args, options)

end

local function loadData()

end

local function configDatabase()

end

local cli_args
if not arg[1] then
    local default_args = require 'flexish_cfg'
    cli_args = default_args
else

    -- Define utility interface
    local usage = [[
]]

    local parser = argparse("Flexilite Shell", "Flexilite Helper Utility")
    --parser:command_target('command') -- name of  command
    parser:argument("command"):args(1) --, "Command: schema, load, query, help, config")
    parser:argument("database"):args(1)
    --parser:command('schema')
    --parser:command('load')
    --parser:command('query')
    --parser:command('help')
    --parser:command('config')
    --parser:argument("database", "Database Name")
    --parser:option("-o --output", "Output file name")
    --parser:option("-c --config", "Path to config file")
    --parser:option("-q --query", "Path to query file")
    --parser:option("-d --database", "Path to SQLite database file")
    cli_args = parser:parse()
end

for i, v in pairs(cli_args) do
    print(i, v)
end

local commandMap = {
    ['schema'] = generateSchema,
    ['load'] = loadData,
    ['query'] = queryDatabase,
    ['config'] = configDatabase,
}

local ff = commandMap[cli_args.command]
if not ff then
    print("Unknown command %s", cli_args.command)
    os.exit()
end

local result = ff(cli_args)

