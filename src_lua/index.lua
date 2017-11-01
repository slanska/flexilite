---
--- Created by slan_ska.
--- DateTime: 2017-10-31 3:10 PM
---

--[[
Keeps list of DBContexts
Handles 'flexi' function
Creates new DBContexts
Disposes DBContext on db connection closing
]]

local DBContext = require('DBContext')
--package.loadlib("/usr/local/opt/sqlite/lib/libsqlite3.dylib","*")
local sqlite = require('lsqlite3complete')

Flexi = {
    -- List of all active contexts
    Contexts = {},

    lastContextID = 0,

    action = function(contextID, action, ...)
        local ff = flexiFuncs[action];
        local ctx = Flexi.getDBContext(contextID)
        ff(ctx, arg, ...)
    end
}

function Flexi:newDBContext(db)
    self.lastContextID = self.lastContextID + 1

    local result = {
        db = db,
        db_ptr = db_ptr,
        contextID = self.lastContextID,
        ClassDefs = {} }

    self.Contexts[self.lastContextID] = result
    --result.__index = DBContext

    return setmetatable(result, DBContext)
end

function Flexi:getDBContext(contextID)
    local result = self.Contexts[contextID]
    if not result then
        error('DBContext with ID ' .. contextID .. ' not found')
    end
    return result
end

function Flexi:closeDBContext(contextID)
    local ctx = self:getDBContext(contextID)
    ctx:close()
end


local db = sqlite.open_memory()
print(db:changes())
db:load_extension('/Users/ruslanskorynin/Documents/Github/slanska/flexilite/bin/libFlexilite')
local ctx = Flexi:newDBContext(db)
ctx:flexiAction('create class', 'Orders', [[]], true)