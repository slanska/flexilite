---
--- Created by slanska
--- DateTime: 2017-11-18 4:56 PM
---

local sqlite3 = require 'lsqlite3complete'
local argparse = require 'argparse'
local SQLiteSchemaParser = require 'sqliteSchemaParser'
local json = require 'cjson'
local os = require 'os'

-- Define utility interface
local usage = [[
]]

local parser = argparse("Flexilite Shell", "Flexilite Helper Utility")
parser:argument("command", "Command: schema, load, query, help, config")
parser:option("-o --output", "Output file name")
parser:option("-c --config", "Path to config file")
parser:option("-q --query", "Path to query file")
parser:option("-d --database", "Path to SQLite database file")

---@param args table
---@param options table
local function generateSchema(args, options)
    local db = sqlite3.open(options.database)
    local sqliteParser = SQLiteSchemaParser:new(db)
    local schema = sqliteParser:parseSchema()
    local out = json.encode(schema)
end

local function queryDatabase(args, options)

end

local function loadData()

end

local function configDatabase()

end

local cli_args = parser:parse()
local commandMap = {
    ['schema'] = generateSchema,
    ['load'] = loadData,
    ['query'] = queryDatabase,
    ['config'] = configDatabase,
}

local ff = commandMap[cli_args]
if not ff then
    print("Unknown command %s", cli_args)
    os.exit()
end

