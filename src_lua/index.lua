---
--- Created by slan_ska.
--- DateTime: 2017-10-31 3:10 PM
---

--[[
Keeps list of DBContexts
Creates new DBContexts
Disposes DBContext on db connection closing
]]

local path = require 'pl.path'
local bits = type(jit) == 'table' and require('bit') or require('bit32')

-- Configure Lua path for libraries
package.path = string.format('%s;%s;%s',
path.abspath(path.relpath('../lib/lua-prettycjson/lib/resty/?.lua')),
path.abspath(path.relpath('../lib/lua-schema/?.lua')), package.path)

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
end

function Flexi:newDBContext(db)
    --local result = {
    --    db = db,
    --    ClassDefs = {} }

    local result = DBContext(db)
    self.Contexts[db] = result
    result.Vars = {}

    -- flexi
    db:create_function('flexi', -1, function(ctx, action, ...)
        local vv = DBContext.flexiAction(result, ctx, action, ...)

        ctx:result(vv)
    end)

    -- bitwise_or
    db:create_aggregate('bitwise_or', 1,

    -- Step callback
    function(ctx, flags)
        local v = bits.bor(ctx:get_aggregate_data() or 0, tonumber(flags))
        ctx:set_aggregate_data(v)
    end,

    -- Final callback
    function(ctx)
        local v = ctx:get_aggregate_data() or 0
        ctx:result_number(v)
    end)

    -- var:get
    db:create_function('var', 1, function(ctx, varName)
        return result.Vars[varName]
    end)

    -- var:set
    db:create_function('var', 2, function(ctx, varName, varValue)
        local v = result.Vars[varName]
        result.Vars[varName] = varValue
        return v
    end)

    return result
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


