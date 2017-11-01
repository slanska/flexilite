--
-- Created by IntelliJ IDEA.
-- User: slanska
-- Date: 2017-10-29
-- Time: 10:32 PM
-- To change this template use File | Settings | File Templates.
--

--[[
Refers to sqlite3 connection
Collection of class definitions
Loads class def from db
Collection of user functions
Executes user functions in sandbox
Pool of prepared statements
User info
Access Permissions
Misc db settings
Finalizes statements on dispose
]]

local ClassDef = require('ClassDef')

local flexiFuncs = {
    ['create class'] = function(action, className, classDef, createVTable)
    end,
    ['alter class'] = function(action, className, classDef, createVTable)
    end,
    ['drop class'] = function(action, className, classDef, createVTable)
    end,
    ['create property'] = function(action, className, classDef, createVTable)
    end,
    ['alter property'] = function(action, className, classDef, createVTable)
    end,
    ['drop property'] = function(action, className, classDef, createVTable)
    end,

}

local DBContext = {}

function DBContext:flexiAction(action, ...)
    local ff = flexiFuncs[action]
    print('action ' .. action)
    if ff == nil then
        error('Flexi action ' .. action .. ' not found')
    end
end

DBContext.__index = DBContext
return DBContext



