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

local DBContext = {}

-- Should be after all FLEXI functions are defined
local flexiFuncs = {
    ['create class'] = require 'flexi_CreateClass',
    ['alter class'] = require 'flexi_AlterClass',
    ['drop class'] = require 'flexi_DropClass',
    ['create property'] = require 'flexi_CreateProperty',
    ['alter property'] = require 'flexi_AlterProperty',
    ['drop property'] = require 'flexi_DropProperty',
    ['configure'] = require 'flexi_Configure',

    ['ping'] = function()
        return 'pong'
    end,

    ['help'] = function(action)

    end,

    ['ping'] = DBContext.flexi_ping,

    ['current user'] = function()

    end,

    ['configure'] = function()

    end,

}

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
    if ff == nil then
        error('Flexi action ' .. action .. ' not found')
    end

    local result = ff(self, ...)

    return result
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
    local stmt = self:getStatement 'select NameID from [.names] where [Value] = :1;'
    stmt:reset()
    stmt:bind { [1] = name }
    for r in stmt:rows() do
        return r[1]
    end

    error('Name [' .. name .. '] not found')
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

-- Loads class definition (as defined in [.classes] and [flexi_prop] tables)
-- First checks if class def has been already loaded, and if so, simply returns it
-- Otherwise, will load class definition from database and add it to the context class def collection
-- If class is not found, will throw error
---@param classId number
---@see ClassDef
---@return ClassDef
function DBContext:LoadClassDefinition(classId)

end

return DBContext



