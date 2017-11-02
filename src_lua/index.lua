---
--- Created by slan_ska.
--- DateTime: 2017-10-31 3:10 PM
---

--[[
Keeps list of DBContexts
Creates new DBContexts
Disposes DBContext on db connection closing
]]

require('socket')
require('mobdebug').start()

local DBContext = require('DBContext')

Flexi = {
    -- List of all active contexts, key is sqlite database handle
    Contexts = {},
}

function Flexi:newDBContext(db)
    local result = {
        db = db,
        ClassDefs = {} }

    self.Contexts[db] = result
    --result.__index = DBContext

    return setmetatable(result, DBContext)
end

function Flexi:getDBContext(db)
    local result = self.Contexts[db]
    if not result then
        error('DBContext with ID ' .. db .. ' not found')
    end

    if result.DB ~= db then
        error("Invalid database handle")
    end

    return result
end

function Flexi:closeDBContext(contextID)
    local ctx = self:getDBContext(contextID)
    ctx:close()
end

local sqlite = require('lsqlite3complete')
local db = sqlite.open_memory()
-- todo use relational path
db:load_extension('/Users/ruslanskorynin/Documents/Github/slanska/flexilite/bin/libFlexilite')
local ctx = Flexi:newDBCbontext(db)