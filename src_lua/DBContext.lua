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

require 'cjson'
--local json = require 'cjson'

local ClassDef = require('ClassDef')
local PropertyDef = require('PropertyDef')
local UserInfo = require('UserInfo')

--- @class DBContext
local DBContext = {}

-- Forward declarations
local flexiFuncs
local flexiHelp

--- Creates a new DBContext, associated with sqlite database connection
--- @param db sqlite3
--- @return DBContext
function DBContext:new(db)
    assert(db)

    local result = {
        db = db,

        -- Cache of most used statements, key is statement SQL
        Statements = {},
        MemDB = nil,
        UserInfo = UserInfo:new(),

        -- Collection of classes. Each class is referenced twice - by ID and Name
        Classes = {},
        Functions = {},

        -- helper constructors
        ClassDef = ClassDef,
        PropertyDef = PropertyDef,

        -- Can be overriden by flexi('config', ...)
        config = {
            createVirtualTable = false
        }
    }

    setmetatable(result, self)
    self.__index = self

    return result
end

--- Utility function to check status returned by SQLite call
--- Throws SQLite error if result ~= SQLITE_OK
--- @param opResult number @comment SQLite integer result. 0 = OK
function DBContext:checkSqlite(opResult)
    if opResult ~= sqlite3.OK and opResult ~= sqlite3.DONE
    and opResult ~= sqlite3.ROW then
        local errMsg = string.format("%d: %s", self.db:error_code(), self.db:error_message())
        error(errMsg)
    end
end

-- Callback to sqlite 'flexi' function
function DBContext:flexiAction(ctx, action, ...)
    local result
    local ff = flexiFuncs[action]
    if ff == nil then
        error('Flexi action ' .. action .. ' not found')
    end

    local args = { ... }
    -- Start transaction
    self.db:exec 'begin'

    local ok, errorMsg = pcall(function()
        result = ff(self, unpack(args))
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
--- @param sql string
--- @return stmt
-- (alias to sqlite3_stmt)
function DBContext:getStatement(sql)
    local result = self.Statements[sql]
    if not result then
        result = self.db:prepare(sql)
        if not result then
            self:checkSqlite(1)
        end

        self.Statements[sql] = result
    else
        result:reset()
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
--- @param className string
--- @param errorIfNotFound boolean @comment optional. If true and class does not exist,
--- error will be thrown
--- @return number @comment class ID or 0 if not found
function DBContext:getClassIdByName(className, errorIfNotFound)
    local row = self:loadOneRow([[
    select ClassID from [.classes] where NameID = (select ID from [.names_props] where Value = :v limit 1);
    ]], { v = className })
    if not row and errorIfNotFound then
        error('Class [' .. className .. '] not found')
    end
    return row and row.ClassID or 0
end

--- @param nameID number
--- @return string
function DBContext:getNameValueByID(nameID)
    local row = self:loadOneRow([[select [Value] from [.names_props] where ID = :v limit 1;]],
    { v = nameID })
    if row then
        return row.Value
    end

    return nil
end

--- Checks if string is a valid name
--- @param name string
--- @return boolean
function DBContext:isNameValid(name)
    return string.match(name, '[_%a][_%w]*') == name
end

---
--- @param classId number
--- @param propName string
--- @param errorIfNotFound boolean @collection optional, If true and property
--- does not exist, error will be thrown
--- @return number @collection property ID or -1 if property does not exist
function DBContext:getPropIdByClassAndNameIds(classId, propName, errorIfNotFound)
    local row = self:loadOneRow([[select PropertyID from [flexi_prop] where ClassID = :c and NameID = :n;"]],
    { c = classId, n = propName }, errorIfNotFound)
    if row then
        return row.PropertyID
    end

    return -1
end

--- @param name string
--- @return number @comment nameID
function DBContext:insertName(name)
    local sql = [[insert  into [.names_props] ([Value], Type) select :v, 0
        where not exists (select ID from [.names_props] where [Value] = :v limit 1);]]
    self:execStatement(sql, { v = name })
    --TODO Use last insert id?
    return self:getNameID(name)
end

--- @param sql string
--- @param params table
function DBContext:execStatement(sql, params)
    local stmt = self:getStatement(sql)
    self:checkSqlite(stmt:bind_names(params))
    local result = stmt:step()
    if result ~= sqlite3.DONE and result ~= sqlite3.ROW then
        self:checkSqlite(result)
    end

    -- return?

end

--- Returns symname ID by its text value
--- @param name string
--- @return number
function DBContext:getNameID(name)
    assert(name)
    local row = self:loadOneRow('select NameID from [.names] where [Value] = :n;', { n = name })
    if not row then

        local cnt = self:loadOneRow([[select * from [.names_props];]], {})
        print(cnt)
        error('Name [' .. name .. '] not found')
    end

    return row.NameID
end

--- Returns property ID based on its class ID and associated name ID
---@param classId number
---@param propNameId number
---@return number @comment -1 if not found, valid ID otherwise
function DBContext:getPropIdByClassIdAndPropNameId(classId, propNameId)
    local row = self:loadOneRow("select PropertyID from [flexi_prop] where ClassID = :c and NameID = :n;",
    { c = classId, n = propNameId })
    if not row then
        return -1
    end

    return row.PropertyID
end

--- @param name string
function DBContext:ensureName(name)
    return self:insertName(name)
end

--- Utility function to load one row from database.
--- @param sql string
--- @param params table
--- table of params to bind
--- @param errorIfNotFound boolean @comment optional.
--- If true and record is not found, error will be thrown
--- @return table @comment columns will be converted to table fields
--- or nil, if no record is found
function DBContext:loadOneRow(sql, params, errorIfNotFound)
    local stmt = self:getStatement(sql)
    self:checkSqlite( stmt:bind_names(params))
    for r in stmt:nrows() do
        return r
    end

    if errorIfNotFound then
        error('Row not found')
    end

    return nil
end

--- Utility function to get statement, bind parameters, and return iterator to iterate through rows
--- @param sql string
--- @param params table
--- @return iterator
function DBContext:loadRows(sql, params)
    local stmt = self:getStatement(sql)
    local ok = stmt:bind_names(params)
    if ok ~= 0 then
        self:checkSqlite(ok)
    end

    return stmt:rows()
end

-- Utility method. Adds instance of ClassDef to DBContext.Classes collection
--- @param classDef ClassDef
--- @return nil
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
--- @param classIdOrName number @comment number or string
--- @param noList boolean @comment If true, class is meant to be used temporarily and will not be added to the DBContextcollection
--- @see ClassDef
--- @return ClassDef @comment or nil, if not found
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

    local sql = type(classIdOrName) == 'string' and
    [[
        select * from [.classes] where NameID = (select ID from [.names_props] where Value = :v limit 1);
    ]]
    or
    [[
        select * from [.classes] where ClassID = :v limit 1);
    ]]
    local cls = self:loadOneRow(sql, { v = classIdOrName })
    if not cls then
        return nil
    end
    result = ClassDef:loadFromDB(self, cls)
    if not noList then
        self:addClassToList(result)
    end

    return result
end

-- Returns schema definition for entire database, single class, or single property
--- @param className string
-- (optional)
--- @param propertyName string
-- (optional)
function DBContext:flexi_Schema(className, propertyName)
    local result
    if not className then
        -- return entire schema
        result = {}

        local stmt = self:getStatement [[select name, id from [.classes]; ]]
        stmt:reset()
        --- @type ClassDef
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
--- @param action string
-- (optional) to provide help for specific action
function DBContext:flexi_Help(action)
    local result = { 'Usage:' }

    local function addActionInfo()
        table.insert(result, table.concat(info[3], ', ') .. ':')
        table.insert(result, info[1])
    end

    if type(action) == 'string' then
        local ff = flexiFuncs[string.lower(action)]
        addActionInfo(flexiHelp[ff])
    else
        for func, info in pairs(flexiHelp) do
            addActionInfo(info)
        end
    end

    return table.concat(result, '\n')
end

-- Handles select flexi('current user', ...)
--- @param userInfo table
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

function DBContext:flexi_ping()
    -- TODO check if flexilite is configured - tables exist etc.
    return 'pong'
end

--- Purges previously softly deleted data
--- @param className string @comment if set, will purge deleted data for that class only
--- @param propName string @comment if set, will purge deleted data for that property only
function DBContext:flexi_vacuum(className, propName)
    -- TODO Hard delete data
end

--- Apply translation for given symnames
--- @param values table
function DBContext:flexi_translate(values)
end

local flexi_CreateClass = require 'flexi_CreateClass'
local flexi_AlterClass = require 'flexi_AlterClass'
local flexi_DropClass = require 'flexi_DropClass'
local flexi_CreateProperty = require 'flexi_CreateProperty'
local flexi_AlterProperty = require 'flexi_AlterProperty'
local flexi_DropProperty = require 'flexi_DropProperty'
local flexi_Configure = require 'flexi_Configure'
local flexi_PropToObject = require 'flexi_PropToObject'
local flexi_ObjectToProp = require 'flexi_ObjectToProp'
local flexi_SplitProperty = require 'flexi_SplitProperty'
local flexi_MergeProperty = require 'flexi_MergeProperty'
local TriggerAPI = require 'Triggers'

-- Initialization should be after all FLEXI functions are defined
-- Variables are declared above

-- Dictionary by action functions, to get metadata about actions
-- Values are 2 item arrays: 1st item - short info, 2nd item - full info
flexiHelp = {
    [flexi_CreateClass.CreateClass] = { '', [[]] },
    [flexi_CreateClass.CreateSchema] = { '', [[]] },
    [flexi_AlterClass] = { '', [[]] },
    [flexi_DropClass] = { '', [[]] },
    [flexi_CreateProperty] = { '', [[]] },
    [flexi_AlterProperty] = { '', [[]] },
    [flexi_DropProperty] = { '', [[]] },
    [flexi_Configure] = { '', [[]] },
    [DBContext.flexi_ping] = { '', [[]] },
    [DBContext.flexi_CurrentUser] = { '', [[]] },
    [flexi_PropToObject] = { '', [[]] },
    [flexi_ObjectToProp] = { '', [[]] },
    [flexi_SplitProperty] = { '', [[]] },
    [flexi_MergeProperty] = { '', [[]] },
    [DBContext.flexi_Schema] = { '', [[]] },
    [DBContext.flexi_Help] = { '', [[]] },
    [DBContext.flexi_LockClass] = { '', [[]] },
    [DBContext.flexi_UnlockClass] = { '', [[]] },
    [DBContext.flexi_vacuum] = { '', [[]] },
    [DBContext.flexi_translate] = { '', [[]] },
    [TriggerAPI.Drop] = { '', [[]] },
    [TriggerAPI.Create] = { '', [[]] },
}

-- Dictionary by action names
flexiFuncs = {
    ['schema create'] = flexi_CreateClass.CreateSchema,
    ['create schema'] = flexi_CreateClass.CreateSchema,
    ['create class'] = flexi_CreateClass.CreateClass,
    ['class create'] = flexi_CreateClass.CreateClass,
    ['create'] = flexi_CreateClass.CreateClass,
    ['alter class'] = flexi_AlterClass,
    ['class alter'] = flexi_AlterClass,
    ['drop class'] = flexi_DropClass,
    ['class drop'] = flexi_DropClass,
    ['create property'] = flexi_CreateProperty,
    ['property create'] = flexi_CreateProperty,
    ['alter property'] = flexi_AlterProperty,
    ['property alter'] = flexi_AlterProperty,
    ['drop property'] = flexi_DropProperty,
    ['property drop'] = flexi_DropProperty,
    ['configure'] = flexi_Configure,
    ['ping'] = DBContext.flexi_ping,
    ['current user'] = DBContext.flexi_CurrentUser,
    ['property to object'] = flexi_PropToObject,
    ['object to property'] = flexi_ObjectToProp,
    ['split property'] = flexi_SplitProperty,
    ['merge property'] = flexi_MergeProperty,
    ['schema'] = DBContext.flexi_Schema,
    ['help'] = DBContext.flexi_Help,
    ['lock class'] = DBContext.flexi_LockClass,
    ['unlock class'] = DBContext.flexi_UnlockClass,
    ['hard delete'] = DBContext.flexi_vacuum,
    ['purge'] = DBContext.flexi_vacuum,
    ['vacuum'] = DBContext.flexi_vacuum,
    ['translate'] = DBContext.flexi_translate,
    ['create trigger'] = TriggerAPI.Create,
    ['trigger create'] = TriggerAPI.Create,
    ['drop trigger'] = TriggerAPI.Drop,
    ['trigger drop'] = TriggerAPI.Drop,

    -- TODO ['convert custom eav'] = ConvertCustomEAV,
}

-- Run once - find all synonyms for actions
for actionName, func in pairs(flexiFuncs) do
    local info = flexiHelp[func] -- should be array of 2 or 3 items
    info[3] = info[3] or {}
    table.insert(info[3], actionName)
end

return DBContext
