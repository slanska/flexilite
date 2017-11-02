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
Handles 'flexi' function

]]

local ClassDef = require('ClassDef')
local UserInfo = require('UserInfo')

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
    ['configure'] = function(action, settings)

    end,
    ['help'] = function(action)

    end,

    ['ping'] = function()

    end,
    ['current user'] = function()

    end,

}

local DBContext = {}

function DBContext:new(db)
    assert(db)

    local result = {
        DB = db,

        -- Cache of most used statements, key is statement SQL
        Statements = {},

        MemDB = nil,

        UserInfo = UserInfo:new(),


    }

    setmetatable(result, self)
    self.__index = self

    return result
end

function DBContext:flexiAction(ctx, action, ...)
    local ff = flexiFuncs[action]
    print('action ' .. action)
    if ff == nil then
        error('Flexi action ' .. action .. ' not found')
    end

    local result = ff(...)

    -- check result, set in context
end

function DBContext:getStatement(sql)
    local result = self.Statements[sql]
    if not result then
        result = self.DB:prepare(sql)
        self.Statements[sql] = result
    end

    return result
end

function DBContext:close()
    -- todo finalize all prepared statements
    for sql, stmt in pairs(self.Statements) do
        if stmt then
            stmt:finalize()
        end
    end
    self.Statements = {}
end

function DBContext:getClassIdByName(className)
    -- todo
end

function DBContext:getNameID(name)
    -- todo
    local stmt = self:getStatement 'select NameID from [.names] where [Value] = :1;'
    stmt:bind { [1] = name }
    stmt:step()
end

function DBContext:getPropIdByClassIdAndPropNameId(classId, propNameId)
    local stmt = self:getStatement "select PropertyID from [flexi_prop] where ClassID = :1 and NameID = :2;"
    stmt:bind { [1] = classId, [2] = propNameId }
    stmt:step()
end

function DBContext:insertName(name)
    -- todo returns name id

    local stmt = self:getStatement [[
    insert or replace into [.names] ([Value], NameID)
                values (:1, (select ID from [.names_props] where Value = :1 limit 1));
    ]]
    stmt:bind { [1] = name }
    stmt:step()
end

function DBContext:flexi_Context_getPropIdByClassIdAndName(classId, propName)
    -- todo
    local stmt = self:getStatement [[
        select ID from [.names_props] where
        PropNameID = (select ID from [.names_props] where [Value] = :1 limit 1)
        and ClassID = :2 limit 1;
    ]]

    stmt:bind { [1] = propName, [2] = classId }
    stmt:step()
end

return DBContext



