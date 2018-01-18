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
local class = require 'pl.class'
local util = require 'pl.utils'

local ClassDef = require('ClassDef')
local PropertyDef = require('PropertyDef')
local UserInfo = require('UserInfo')
local AccessControl = require 'AccessControl'
local DBObject = require 'DBObject'
local EnumManager = require 'EnumManager'


--[[
Maintains list of (normally deferred) actions to execute
]]
---@class ActionList
---@field tags table
---@field list table
local ActionList = class()

-- constructor
function ActionList:_init(DBContext)
    self:Clear()
end

function ActionList:Add(tag, func, arg1, arg2, arg3)
    if tag then
        if self.tags[tag] then
            -- already registered
            return
        end
        self.tags[tag] = true
    end

    local item = { func = func, arg1 = arg1, arg2 = arg2, arg3 = arg3 }
    table.insert(self.list, item)
end

---@param clearWhenDone boolean
function ActionList:Run(clearWhenDone)
    for idx, item in ipairs(self.list) do
        if item.func then
            item.func(item.arg1, item.arg2, item.arg3)
        end
    end
    if clearWhenDone then
        self:Clear()
    end
end

function ActionList:Clear()
    ---@type table @comment array
    self.list = {}

    ---@type table @comment map by tag
    self.tags = {}
end

---@class DBContextConfig
---@field createVirtualTable boolean

---@class DBContext
---@field db sqlite3
---@field Statements table
---@field MemDB table
---@field UserInfo UserInfo
---@field Classes table
---@field Functions table
---@field ClassProps table
---@field Objects tables
---@field CUObjects table
---@field ClassDef ClassDef
---@field PropertyDef PropertyDef
---@field AccessControl AccessControl
---@field EnumManager EnumManager
---@field SchemaChanged boolean
---@field DeferredActions ActionList
---@field config DBContextConfig
local DBContext = class()

-- Forward declarations
local flexiFuncs
local flexiMeta

--- Creates a new DBContext, associated with sqlite database connection
--- @param db sqlite3
--- @return DBContext
function DBContext:_init(db)
    assert(db)

    self.db = db

    -- Cache of prepared statements, key is statement SQL
    self.Statements = {}
    self.MemDB = nil
    self.UserInfo = UserInfo()

    -- Collection of classes. Each class is referenced twice - by ID and Name
    self.Classes = {}

    -- Global list of registered functions. Each function is referenced twice - by ID and name
    self.Functions = {}

    -- Global list of class property definitions (by property ID)
    self.ClassProps = {}

    -- Cache of loaded objects (map by object ID). Exists only during time of request. Gets reset after request is complete
    self.Objects = {}
    -- Collection of created/updated objects
    self.CUObjects = {}

    -- helper constructors and singletons
    self.ClassDef = ClassDef
    self.PropertyDef = PropertyDef

    -- Singletons
    self.AccessControl = AccessControl(self)
    self.EnumManager = EnumManager(self)

    self.SchemaChanged = false

    ---@type ActionList
    self.DeferredActions = ActionList()

    -- Can be overridden by flexi('config', ...)
    self.config = {
        createVirtualTable = false
    }

    self:initMemoizeFunctions()
end

--[[ Loads existing object by ID. propIds define subset of values to load (passing subset of properties used
for better performance). Note that once loaded with subset of values, object will be manipulated as is, and non-loaded
properties will be loaded on demand. Also, when object gets edited, its entire content is loaded.
]]
---@param id number
---@param propIds table|nil @comment list of property IDs to load
---@return DBObject
function DBContext:LoadObject(id, propIds)
    local result = self.CUObjects[id]
    if not result and id > 0 then
        result = self.Objects[id]

        if not result then
            -- TODO Check access rules for class and specific object
            result = DBObject { ID = id, PropIDs = propIds, DBContext = self }
            self.Objects[id] = result
        end
    end
    return result
end

-- Starts editing an existing objects
---@param id number
---@return DBObject
function DBContext:EditObject(id)
    -- TODO Check access rules for class and specific object
    local result = assert(self:LoadObject(id), string.format('Object with ID %d not found', id))
    result:LoadAllValues()

    result = result:CloneForEdit()
    self.CUObjects[id] = result
    return result
end

-- Deletes object with given ID
---@param id number
function DBContext:DeleteObject(id)
    -- TODO Check access rules for class and specific object
end

-- Creates new object of given class, and optionally sets new data payload
---@param classDef ClassDef
---@param data table|nil
function DBContext:NewObject(classDef, data)
    local result = DBObject { ClassDef = classDef, ID = self:GetNewObjectID(), Data = data }
    self.CUObjects[result.ID] = result
    return result
end

function DBContext:GetNewObjectID()
    self.lastNewObjectID = (self.lastNewObjectID or 0) - 1
    return self.lastNewObjectID
end

--- Utility function to check status returned by SQLite call
--- Throws SQLite error if result ~= SQLITE_OK
--- @param opResult number @comment SQLite integer result. 0 = OK
function DBContext:checkSqlite(opResult)
    if opResult ~= sqlite3.OK and opResult ~= sqlite3.DONE
            and opResult ~= sqlite3.ROW then
        local errMsg = string.format("SQLite error code %d: %s", self.db:error_code(), self.db:error_message())
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

    local meta = flexiMeta[ff]

    self.SchemaChanged = false

    local args = { ... }
    -- Start transaction
    self.db:exec 'begin'

    local ok, errorMsg = xpcall(function()
        -- Check if schema has been changed since last call
        local uv = self:loadOneRow([[pragma user_version;]])
        if self.SchemaVersion ~= uv then
            self:flushSchemaCache()
        end

        self.DeferredActions:Clear()

        result = ff(self, unpack(args))

        if meta.schemaChange or self.SchemaChanged then
            self:execStatement(string.format([[pragma user_version=%d;]], uv.user_version))
        end

        self.DeferredActions:Run(true)

        self.db:exec 'commit'
    end
    ,
            function(error)
                -- TODO
                print(debug.traceback(tostring(error)))
            end)

    if not ok then
        self.db:exec 'rollback'
        ctx:result_error(errorMsg)
    end

    self.DeferredActions:Clear()
    self:flushDataCache()
    self.AccessControl:flushCache()

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

function DBContext:finalizeStatements()
    for _, stmt in pairs(self.Statements) do
        if stmt then
            stmt:finalize()
        end
    end
    self.Statements = {}
end

function DBContext:close()
    self:finalizeStatements()
end

--- Finds class ID by its name
--- @param className string
--- @param errorIfNotFound boolean @comment optional. If true and class does not exist,
--- error will be thrown
--- @return number @comment class ID or 0 if not found
function DBContext:getClassIdByName(className, errorIfNotFound)
    local row = self:loadOneRow([[
    select ClassID from [.classes] where NameID = (select ID from [.sym_names] where Value = :v limit 1);
    ]], { v = className })
    if not row and errorIfNotFound then
        error('Class [' .. className .. '] not found')
    end
    return row and row.ClassID or 0
end

--- @param nameID number
--- @return string
function DBContext:getNameValueByID(nameID)
    local row = self:loadOneRow([[select [Value] from [.sym_names] where ID = :v limit 1;]],
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
    local sql = [[insert  into [.sym_names] ([Value]) select :v
        where not exists (select ID from [.sym_names] where [Value] = :v limit 1);]]
    self:execStatement(sql, { v = name })
    --TODO Use last insert id?
    return self:getNameID(name)
end

--- @param sql string
--- @param params table
function DBContext:execStatement(sql, params)
    local stmt = self:getStatement(sql)
    if params then
        self:checkSqlite(stmt:bind_names(params))
    end
    local result = stmt:step()
    if result ~= sqlite3.DONE and result ~= sqlite3.ROW then
        self:checkSqlite(result)
    end
end

--- Returns symname ID by its text value
--- @param name string
--- @return number
function DBContext:getNameID(name)
    assert(name)
    local row = self:loadOneRow('select NameID from [.names] where [Value] = :n;', { n = name })
    if not row then

        local cnt = self:loadOneRow([[select * from [.sym_names];]], {})
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
    if params then
        self:checkSqlite( stmt:bind_names(params))
    end
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
    assert(type(classDef.ClassID) == 'number')
    self.Classes[classDef.ClassID] = classDef
    self.Classes[classDef.Name.text] = classDef
end

-- Loads class definition (as defined in [.classes] and [flexi_prop] tables)
-- First checks if class def has been already loaded, and if so, simply returns it
-- Otherwise, will load class definition from database and add it to the context class def collection
-- If class is not found, will throw error
--- @param classIdOrName number @comment number or string
---@param mustExist boolean
--- @see ClassDef
--- @return ClassDef @comment or nil, if not found
function DBContext:getClassDef(classIdOrName, mustExist)
    local result = self.Classes[classIdOrName]

    -- Check if class already loaded
    if result then
        if type(classIdOrName) == 'string' then
            assert(result.Name.text == classIdOrName)
        else
            assert(result.ID == classIdOrName)
        end
        return result
    end

    -- If loaded, ensure if it wasn't updated

    local sql = [[select c.* from (select *, (select Value from [.sym_names] where ID = NameID limit 1) as Name from [.classes]) as c]]
    if type(classIdOrName) == 'string' then
        sql = sql .. [[ where c.Name = :1 limit 1; ]]
    else
        sql = sql .. [[ where c.ClassID = :1 limit 1;]]
    end
    local classRow = self:loadOneRow(sql, { ['1'] = classIdOrName })
    if not classRow then
        if mustExist then
            error(string.format('Class %s not found', classIdOrName))
        end
        return nil
    end
    result = ClassDef { data = classRow, DBContext = self }
    self:addClassToList(result)

    self:initMixinProperties()

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
            local cls = self:getClassDef(row.id)
        end

    elseif not propertyName then
        -- return class
        local cls = self:getClassDef(className)
        result = cls.toJSON()
    else
        -- return property
        local cls = self:getClassDef(className)
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

    local function addActionInfo(info)
        table.insert(result, table.concat(info.actions, ', ') .. ':')
        table.insert(result, info.shortInfo)
    end

    if type(action) == 'string' then
        local ff = flexiFuncs[string.lower(action)]
        addActionInfo(flexiMeta[ff])
    else
        for func, info in pairs(flexiMeta) do
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

    self:flushCurrentUserCheckPermissions()

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

-- Init cached functions
function DBContext:initMemoizeFunctions()

    -- Return array of mixin properties for given class ID
    self.GetClassMixinProperties = util.memoize(function(classID)
        local classDef = self:getClassDef(classID)
        return tablex.filter(tablex.values(classDef.Properties), function(propDef)
            return propDef.rules.type == 'mixin'
        end)
    end)

    -- Return array of mixin properties for given class ID
    self.GetClassReferenceProperties = util.memoize(function(classID)
        local classDef = self:getClassDef(classID)
        return tablex.filter(tablex.values(classDef.Properties), function(propDef)
            return propDef:isReference()
        end)
    end)

    -- Return array of mixin properties for given class ID
    self.GetNestedAndMasterProperties = util.memoize(function(classID)
        local classDef = self:getClassDef(classID)
        return tablex.filter(tablex.values(classDef.Properties), function(propDef)
            return propDef.rules.type == 'nested'
        end)
    end)
end

function DBContext:flushSchemaCache()
    self.Classes = {}
    self.ClassProps = {}
    self.Functions = {}
    self.Objects = {}
    self:initMemoizeFunctions()
    self:flushCurrentUserCheckPermissions()
    self:finalizeStatements()
end

function DBContext:flushDataCache()
    self.Objects = {}
end

---@param objectID number
---@return DBObject
function DBContext:getObject(objectID)
    local result = self.Objects[objectID]
    if result then
        return result
    end

    result = DBObject(self, nil, objectID)
    self.Objects[objectID] = result
    return result
end

--[[ Initializes memoize (cache-based) functions to get actual permission for given database objects
 Makes the following functions available:
 * ensureCurrentUserAccessForProperty
 * ensureCurrentUserAccessForClass

 These functions are reset on schema or current user change
]]
function DBContext:flushCurrentUserCheckPermissions()
    self.ensureCurrentUserAccessForProperty = util.memoize(function(propID, op)
        self.AccessControl:ensureCurrentUserAccessForProperty(propID, op)
    end)

    self.ensureCurrentUserAccessForClass = util.memoize(function(classID, op)
        self.AccessControl:ensureCurrentUserAccessForClass(classID, op)
    end)
end

-- Internal method. Prepares ad hoc SQL statement and binds parameters
---@param sql string
---@param params table
---@return lsqlite.stmt
function DBContext:getAdhocStmt(sql, params)
    local result = self.db:prepare(sql)
    if not result then
        self:checkSqlite(1)
    end

    if params then
        self:checkSqlite(result:bind_names(params))
    end
    return result
end

-- Executes ad hoc SQL
---@param sql string
---@param params table
function DBContext:ExecAdhocSql(sql, params)
    local stmt = self:getAdhocStmt(sql, params)
    local result = stmt:step()
    if result ~= sqlite3.DONE and result ~= sqlite3.ROW then
        self:checkSqlite(result)
    end
end

--- Utility function to get statement, bind parameters, and return iterator to iterate through rows
--- @param sql string
--- @param params table
--- @return iterator
function DBContext:LoadAdhocRows(sql, params)
    local stmt = self:getAdhocStmt(sql, params)
    return stmt:rows()
end

local flexi_CreateClass = require 'flexi_CreateClass'
local flexi_AlterClass = require 'flexi_AlterClass'
local flexi_DropClass = require 'flexi_DropClass'
local flexi_CreateProperty = require('flexi_CreateProperty').CreateProperty
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
-- Values are tables: { shortInfo:string, fullInfo:string, schemaChange:boolean, actionNames:Array }
flexiMeta = {
    [flexi_CreateClass.CreateClass] = { shortInfo = '', fullInfo = [[]], schemaChange = true },
    [flexi_CreateClass.CreateSchema] = { shortInfo = '', fullInfo = [[]], schemaChange = true },
    [flexi_AlterClass] = { shortInfo = '', fullInfo = [[]], schemaChange = true },
    [flexi_DropClass] = { shortInfo = '', fullInfo = [[]], schemaChange = true },
    [flexi_CreateProperty] = { shortInfo = '', fullInfo = [[]], schemaChange = true },
    [flexi_AlterProperty] = { shortInfo = '', fullInfo = [[]], schemaChange = true },
    [flexi_DropProperty] = { shortInfo = '', fullInfo = [[]], schemaChange = true },
    [flexi_Configure] = { shortInfo = '', fullInfo = [[]], schemaChange = true },
    [DBContext.flexi_ping] = { shortInfo = '', fullInfo = [[]] },
    [DBContext.flexi_CurrentUser] = { shortInfo = '', fullInfo = [[]] },
    [flexi_PropToObject] = { shortInfo = '', fullInfo = [[]], schemaChange = true },
    [flexi_ObjectToProp] = { shortInfo = '', fullInfo = [[]], schemaChange = true },
    [flexi_SplitProperty] = { shortInfo = '', fullInfo = [[]], schemaChange = true },
    [flexi_MergeProperty] = { shortInfo = '', fullInfo = [[]], schemaChange = true },
    [DBContext.flexi_Schema] = { shortInfo = '', fullInfo = [[]] },
    [DBContext.flexi_Help] = { shortInfo = '', fullInfo = [[]] },
    [DBContext.flexi_LockClass] = { shortInfo = '', fullInfo = [[]] },
    [DBContext.flexi_UnlockClass] = { shortInfo = '', fullInfo = [[]] },
    [DBContext.flexi_vacuum] = { shortInfo = '', fullInfo = [[]] },
    [DBContext.flexi_translate] = { shortInfo = '', fullInfo = [[]] },
    [TriggerAPI.Drop] = { shortInfo = '', fullInfo = [[]], schemaChange = true },
    [TriggerAPI.Create] = { shortInfo = '', fullInfo = [[]], schemaChange = true },
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

--[[

    /*
 Change class ID of given objects. Updates schemas and possibly columns A..J to match new class schema
 */
move to another class

    /*
 Removes duplicated objects. Updates references to point to a new object. When resolving conflict, selects object
 with larger number of references to it, or object that was updated more recently.
 */
remove duplicates

    /*
 Splits objects vertically, i.e. one set of properties goes to class A, another - to class B.
 Resulting objects do not have any relation to each other
 */
structural split

    /*
 Joins 2 non related objects into single object, using optional property map. Corresponding objects will be found using sourceKeyPropIDs
 and targetKeyPropIDs
 */
structural merge

reorderArrayItems

    /*
 Returns report on results of last refactoring action
 */
getLastActionReport

    /*
 Retrieves list of invalid objects for the given class (objects which do not pass property rules)
 Returns list of object IDs.
 @className - class name to perform validation on
 @markAsnInvalid - if set to true, invalid objects will be marked with CTLO_HAS_INVALID_DATA
 Note that all objects will be affected and valid objects will get this flag cleared.
 */
 get invalid objects

]]

-- TODO ['convert custom eav'] = ConvertCustomEAV,
}

-- Run once - find all synonyms for actions
for actionName, func in pairs(flexiFuncs) do
    local info = flexiMeta[func] -- should be array of 2 or 3 items
    info.actionNames = info[3] or {}
    table.insert(info.actionNames, actionName)
end

return DBContext
