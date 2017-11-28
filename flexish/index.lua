---
--- Created by slanska
--- DateTime: 2017-11-18 4:56 PM
---

local sqlite3 = require 'lsqlite3complete'
local SQLiteSchemaParser = require 'sqliteSchemaParser'
local json = require 'cjson'
local os = require 'os'
local path = require 'pl.path'
local lapp = require 'pl.lapp'

---@param cli_args table
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
    local schemaJson = json.encode(schema)

    if cli_args.output == nil or cli_args.output == '' then
        io.stdout:write(schemaJson)
    else
        if not path.isabs(cli_args.output) then
            cli_args.output = path.abspath(path.relpath(cli_args.output))
        end
        local f = io.open(cli_args.output, 'w')
        f:write(schemaJson)
        f:close()
    end
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
    cli_args = lapp [[
    Flexilite Shell Utility
    <command> (string) 'schema' | 'load' | 'query' | 'help' | 'config'
    <database> (string) Path to SQLite database file
    -o, --output (file-out default '') Output file path
    -c, --config (file-in default '') Path to config file
    -q, --query (file-in default '') Path to query file
     ]]
end

require 'pl.pretty'.dump(cli_args)

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

