---
--- Created by slan_ska.
--- DateTime: 2017-10-31 3:10 PM
---

--[[
Keeps list of DBContexts
Creates new DBContexts
Disposes DBContext on db connection closing
]]


local DBContext = require('DBContext')

Flexi = {
    -- List of all active contexts, key is sqlite database handle
    Contexts = {},
}

--[[
Gateway to handle all 'select flexi()' requests.
- Finds DBContext by context ctx
- Calls DBContext.processFlexiAction
TODO processFlexiAction ???

- Processing is done within protected call (pcall)
- All errors are converted to ctx errors and reported back to caller
]]
function Flexi.flexiFunction(ctx, action, ...)
    ctx:result_string 'wfh?'
    return 0
    --print('User_data: ' .. ctx:user_data())
end

function Flexi:newDBContext(db)
    local result = {
        db = db,
        ClassDefs = {} }

    self.Contexts[db] = result
    --result.__index = DBContext

    db:create_function('flexi', -1, function(ctx, action, ...)
        local tt = type(db)

        ctx:result_string('WTF?!')
    end)

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

--local sqlite = require('lsqlite3complete')
--local db = sqlite.open_memory()
---- todo use relational path
--db:load_extension('/Users/ruslanskorynin/Documents/Github/slanska/flexilite/bin/libFlexilite')
--local ctx = Flexi:newDBCbontext(db)


