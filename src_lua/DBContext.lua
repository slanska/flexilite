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

local json = require 'cjson'

local ClassDef = require('ClassDef')
local UserInfo = require('UserInfo')

---@class DBContext
local DBContext = {}

-- Forward declaration
local flexiFuncs

--- Creates a new DBContext, associated with sqlite database connection
---@param db sqlite3
---@return DBContext
function DBContext:new(db)
    assert(db)

    local result = {
        DB = db,

        -- Cache of most used statements, key is statement SQL
        Statements = {},

        MemDB = nil,

        UserInfo = UserInfo:new(),

        -- Collection of classes. Each class is referenced twice - by ID and Name
        Classes = {},

        Functions = {},

        -- Can be overriden by flexi('config', ...)
        config = {
            createVirtualTable = false
        }
    }

    setmetatable(result, self)
    self.__index = self

    return result
end

-- Callback to sqlite 'flexi' function
function DBContext:flexiAction(ctx, action, ...)
    local result
    local ff = flexiFuncs[action]
    if ff == nil then
        error('Flexi action ' .. action .. ' not found')
    end

    -- Start transaction
    self.db:exec 'begin'

    local ok, errorMsg = pcall(function()
        result = ff(self, ...)
        self.db:exec 'commit'
    end)

    if not ok then
        self.db:exec 'rollback'
        error(errorMsg)
    end

    return result
end

-- Utility method to obtain prepared sqlite statement
-- All prepared statements are kept in DBContext.Statements pool and accessed by sql as key
---@param sql string
---@return stmt
-- (alias to sqlite3_stmt)
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
    for _, stmt in pairs(self.Statements) do
        if stmt then
            stmt:finalize()
        end
    end
    self.Statements = {}
end

--- Finds class ID by its name
---@param className string
---@return number
function DBContext:getClassIdByName(className)
    local row = self:loadOneRow([[
    select ClassID from [.classes] where NameID = (select ID from [.names_props] where Value = :1 limit 1);
    ]], { [1] = className })
    if not row then
        error('Class [' .. className .. '] not found')
    end
    return row.ClassID
end

--- Checks if string is a valid name
---@param name string
---@return boolean
function DBContext:isNameValid(name)
    return string.match(name, '[_%a][_%w]*') == name
end

function DBContext:getNameID(name)
    local row = self:loadOneRow() 'select NameID from [.names] where [Value] = :1;'
    if not row then
        error('Name [' .. name .. '] not found')
    end

    return row.NameID
end

function DBContext:getPropIdByClassIdAndPropNameId(classId, propNameId)
    local stmt = self:getStatement "select PropertyID from [flexi_prop] where ClassID = :1 and NameID = :2;"
    stmt:bind { [1] = classId, [2] = propNameId }
    stmt:step()
end

-- Inserts a new name to .name_props table
---@param name string
---@return nil
function DBContext:insertName(name)
    -- todo returns name id

    local stmt = self:getStatement [[
    insert or replace into [.names] ([Value], NameID)
                values (:1, (select ID from [.names_props] where Value = :1 limit 1));
    ]]
    stmt:bind { [1] = name }
    stmt:step()
end

function DBContext:getPropIdByClassIdAndName(classId, propName)
    -- todo
    local stmt = self:getStatement [[
        select ID from [.names_props] where
        PropNameID = (select ID from [.names_props] where [Value] = :1 limit 1)
        and ClassID = :2 limit 1;
    ]]

    stmt:bind { [1] = propName, [2] = classId }
    stmt:step()
end

--- Utility function to load one row from database.
---@param sql string
---@param params table
--- table of params to bind
---@return table
--- or nil, if no record is found
function DBContext:loadOneRow(sql, params)
    local stmt = self:getStatement(sql)
    stmt:bind(params)
    for r in stmt:rows() do
        return r
    end

    return nil
end

-- Utility method. Adds instance of ClassDef to DBContext.Classes collection
---@param classDef ClassDef
---@return nil
function DBContext:addClassToList(classDef)
    assert(classDef)
    assert(type(classDef.ID) == 'number')
    assert(type(classDef.Name) == 'string')
    self.Classes[classDef.ID] = classDef
    self.Classes[classDef.Name] = classDef
end

-- Loads class definition (as defined in [.classes] and [flexi_prop] tables)
-- First checks if class def has been already loaded, and if so, simply returns it
-- Otherwise, will load class definition from database and add it to the context class def collection
-- If class is not found, will throw error
---@param classIdOrName number @comment number or string
---@param noList boolean @comment If true, class is meant to be used temporarily and will not be added to the DBContextcollection
---@see ClassDef
---@return ClassDef
function DBContext:LoadClassDefinition(classIdOrName, noList)
    local result = self.Classes[classId]
    if result then
        if type(classIdOrName) == 'string' then
            assert(result.Name == classIdOrName)
        else
            assert(result.ID == classIdOrName)
        end
        return result
    end

    local cls = self:loadOneRow([[]], {})
    result = ClassDef:loadFromDB(self, cls)
    if not noList then
        self:addClassToList(result)
    end

    return result
end

-- Returns schema definition for entire database, single class, or single property
---@param className string
-- (optional)
---@param propertyName string
-- (optional)
function DBContext:flexi_Schema(className, propertyName)
    local result
    if not className then
        -- return entire schema
        result = {}

        local stmt = self:getStatement [[select name, id from [.classes]; ]]
        stmt:reset()
        ---@type ClassDef
        for row in stmt:rows() do
            -- Temp load - do not add to collection
            local cls = self:LoadClassDefinition(row.id)


        end

    elseif not propertyName then
        -- return class
        local cls = self:LoadClassDefinition(className)
        result = cls.toJSON()
    else
        -- return property
        local cls = self:LoadClassDefinition(className)
        local prop = cls:getProperty(propertyName)
        result = prop.toJSON()
    end
    return json.encode(result)
end

-- Handler for select flexi('help', ...)
---@param action string
-- (optional) to provide help for specific action
function DBContext:flexi_Help(action)

end

-- Handles select flexi('current user', ...)
---@param userInfo table
-- string (userID) or table (UserInfo)
function DBContext:flexi_CurrentUser(userInfo, roles, culture)
    if not userInfo and not roles and not culture then
        return json.encode(self.UserInfo)
    end

    local dd = json.decode(userInfo)
    if type(dd) == 'string' then
        self.UserInfo.UserID = dd
    else
        self.UserInfo = UserInfo:new(dd)
        return 'Current user info updated'
    end

    if roles then
        self.UserInfo.Roles = json.decode(roles)
    end
    if culture then
        self.UserInfo.Culture = culture
    end

    return 'Current user info updated'
end

function DBContext:flexi_LockClass(className)

end

function DBContext:flexi_UnlockClass(className)

end

-- Should be after all FLEXI functions are defined
flexiFuncs = {
    ['create class'] = require 'flexi_CreateClass',
    ['class create'] = require 'flexi_CreateClass',
    ['alter class'] = require 'flexi_AlterClass',
    ['class alter'] = require 'flexi_AlterClass',
    ['drop class'] = require 'flexi_DropClass',
    ['class drop'] = require 'flexi_DropClass',
    ['create property'] = require 'flexi_CreateProperty',
    ['property create'] = require 'flexi_CreateProperty',
    ['alter property'] = require 'flexi_AlterProperty',
    ['property alter'] = require 'flexi_AlterProperty',
    ['drop property'] = require 'flexi_DropProperty',
    ['property drop'] = require 'flexi_DropProperty',
    ['configure'] = require 'flexi_Configure',

    ['ping'] = DBContext.flexi_ping,

    ['current user'] = DBContext.flexi_CurrentUser,

    ['property to object'] = require 'flexi_PropToObject',
    ['object to property'] = require 'flexi_ObjectToProp',
    ['split property'] = require 'flexi_SplitProperty',
    ['merge property'] = require 'flexi_MergeProperty',
    ['schema'] = DBContext.flexi_Schema,
    ['help'] = DBContext.flexi_Help,
    ['lock class'] = DBContext.flexi_LockClass,
    ['unlock class'] = DBContext.flexi_UnlockClass,
    ['invalidate class'] = {},

}

return DBContext
