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

local json = cjson or require 'cjson'
local class = require 'pl.class'
local util = require 'pl.utils'

local ClassDef = require('ClassDef')
local PropertyDef = require('PropertyDef')
local UserInfo = require('UserInfo')
local AccessControl = require 'AccessControl'
local DBObject = require 'DBObject'
local RefDataManager = require 'RefDataManager'
local Constants = require 'Constants'
local DictCI = require('Util').DictCI
local sqlite3 = sqlite3 or require 'sqlite3'
local List = require 'pl.List'
local Events = require 'EventEmitter'
local string = _G.string
local table = _G.table

-- to fix bug of missing values when running Flexilite in flexi_test app
sqlite3.OK = 0
sqlite3.ROW = 100
sqlite3.DONE = 101

local flexiRel = require 'flexi_rel_vtable'
local dbg = nil -- future reference to 'debugger.lua'

---@class ActionQueue : List
---@field DBContext DBContext
local ActionQueue = class(List)

---@param DBContext DBContext
function ActionQueue:_init(DBContext)
    self:super()
    self.DBContext = DBContext
end

---@class ActionQueueItem
---@field action fun(self: DBContext, params: any): any
---@field params any

---@param act function
function ActionQueue:enqueue(act, params)
    -->
    --require('debugger')()

    ---@type ActionQueueItem
    local item = { action = act, params = params}
    self:append(item)
end

---@return function
function ActionQueue:dequeue()
    if #self > 0 then
        local result = self[1]
        self:remove(1)
        return result
    end

    return nil
end

function ActionQueue:run()
    while #self > 0 do
        local item = self:dequeue()

        if type(item) ~= 'table' then
            -->>
            require('debugger')()
        end

        if item and item.action then
            item.action(item.params, self.DBContext)
        end
    end
end

---@param self DictCI
---@param classDef ClassDef
local function ClassCollection_add(self, classDef)
    assert(classDef)
    assert(type(classDef.ClassID) == 'number')
    assert(classDef.Name and type(classDef.Name.text) == 'string')

    self[classDef.ClassID] = classDef
    self[classDef.Name.text] = classDef
end

-------------------------------------------------------------------------------
-- DBContext
-------------------------------------------------------------------------------

---@class DBContextConfig
---@field createVirtualTable boolean

---@class DBContext
---@field db userdata @comment sqlite3 - sqlite database handler
---@field Statements table <string, userdata> @comment <string, sqlite3_stmt>
---@field MemDB table
---@field UserInfo UserInfo
---@field Classes DictCI
---@field Functions table @comment TODO use Function class
---@field ClassProps table<number, PropertyDef>
---@field Objects table <number, DBObject>
---@field DirtyObjects table <number, DBObject>
---@field ClassDef ClassDef @comment constructor
---@field PropertyDef PropertyDef @comment constructor
---@field AccessControl AccessControl
---@field RefDataManager RefDataManager
---@field SchemaChanged boolean
---@field ActionQueue ActionQueue
---@field config DBContextConfig
---@field flexirel FlexiRelVTable
---@field debugMode boolean
---@field NAMClasses DictCI @comment new-and-modified classes before committing schema changes
---@field events Events
local DBContext = class()

DBContext.EVENT_NAMES = {
    FLUSH_SCHEMA_DATA = 'FLUSH_SCHEMA_DATA',
}

-- Forward declarations
local flexiFuncs
local flexiMeta

--- Creates a new DBContext, associated with sqlite database connection
--- @param db userdata @comment sqlite3
--- @return DBContext
function DBContext:_init(db)
    self.db = assert(db, 'Expected sqlite3 database but nil was passed')

    -- Cache of prepared statements, key is statement SQL
    self.Statements = {}
    self.MemDB = nil
    self.UserInfo = UserInfo()

    -- Collection of classes. Each class is referenced twice - by ID and Name
    self.Classes = DictCI()

    -- Global list of registered functions. Each function is referenced twice - by ID and name
    self.Functions = {}

    -- Global list of class property definitions (by property ID)
    self.ClassProps = {}

    -- Cache of loaded objects (map by object ID). Exists only during time of request. Gets reset after request is complete
    self.Objects = {}

    -- helper constructors and singletons
    self.ClassDef = ClassDef
    self.PropertyDef = PropertyDef

    -- Singletons
    self.AccessControl = AccessControl(self)
    self.RefDataManager = RefDataManager(self)

    self.SchemaChanged = false

    self:setActionQueue()

    -- Can be overridden by flexi('config', ...)
    self.config = {
        createVirtualTable = false
    }

    self.Vars = {}

    -- flexi
    self.db:create_function('flexi', -1, function(ctx, action, ...)
        if self.debugMode then
            local args = { ... }
            dbg.call(function()
                self.flexiAction(self, ctx, action, unpack(args))
            end)
        else
            self.flexiAction(self, ctx, action, ...)
        end
    end)

    -- var:get
    self.db:create_function('var', 1, function(ctx, varName)
        ctx:result(self.Vars[varName])
    end)

    -- var:set
    self.db:create_function('var', 2, function(ctx, varName, varValue)
        local v = self.Vars[varName]
        self.Vars[varName] = varValue
        self:result(v)
    end)

    self:initMemoizeFunctions()

    self.flexirel = flexiRel

    self.debugMode = false

    self.events = Events:new()
end

--[[ Loads existing object by ID. propIds define subset of values to load (passing subset of properties used
for better performance). Note that once loaded with subset of values, object will be manipulated as is, and non-loaded
properties will be loaded on demand. Also, when object gets edited, its entire content is loaded.
]]
---@param id number
---@param propIds table|nil @comment list of property IDs to load
---@param forUpdate boolean | nil
---@param objRow table | nil @comment row of [.objects]
---@return DBObject
function DBContext:LoadObject(id, propIds, forUpdate, objRow)
    local result = self.Objects[id]

    if not result then
        local op = forUpdate and Constants.OPERATION.UPDATE or Constants.OPERATION.READ
        -- TODO Check access rules for class and specific object
        result = DBObject({ ID = id, PropIDs = propIds, DBContext = self, ObjRow = objRow }, op)
        self.Objects[id] = result
    end
    return result
end

-- Starts editing an existing objects
---@param id number
---@return DBObject
function DBContext:EditObject(id)
    -- TODO Check access rules for class and specific object
    local result = assert(self:LoadObject(id, nil, false, nil), string.format('Object with ID %d not found', id))
    result:LoadAllValues()
    result:Edit()
    return result
end

---@param obj DBObject
function DBContext:StartEditObject(obj)
    local result = obj:CloneForEdit()
    result.old = obj
    obj.new = result
    self.DirtyObjects[obj.ID] = result
    return result
end

-- Deletes object with given ID
---@param id number
function DBContext:DeleteObject(id)
    -- TODO Check access rules for class and specific object

    local result = self:EditObject(id)
    result.ID = 0
    return result
end

-- Creates new object of given class, and optionally sets new data payload
---@param classDef ClassDef
---@param data table|nil
function DBContext:NewObject(classDef, data)
    local pp = { ClassDef = classDef, ID = self:GetNewObjectID(), Data = data }
    local result = DBObject(pp, Constants.OPERATION.CREATE)
    self.Objects[pp.ID] = result
    return result
end

function DBContext:GetNewObjectID()
    self.lastNewObjectID = (self.lastNewObjectID or 0) - 1
    return self.lastNewObjectID
end

--- Utility function to check status returned by SQLite call
--- Throws SQLite error if result ~= SQLITE_OK, SQLITE_DONE or SQLITE_ROW
--- @param opResult number @comment SQLite integer result. 0 = OK
function DBContext:checkSqlite(opResult)
    if opResult ~= sqlite3.OK and opResult ~= sqlite3.DONE
            and opResult ~= sqlite3.ROW then
        local errMsg = string.format("SQLite error code %d: %s",
                self.db:error_code(), self.db:error_message())

        error(errMsg)
    end
end

-- Callback to sqlite 'flexi' function
function DBContext:flexiAction(ctx, action, ...)
    local result
    local ff = flexiFuncs[action]
    if ff == nil then
        ctx:result_error('Flexi action ' .. action .. ' not found')
        return
    end

    local meta = flexiMeta[ff]

    self.SchemaChanged = false

    local args = { ... }
    -- Start transaction
    self.db:exec 'begin'

    local errorMsg = ''

    local function execute()
        -- Check if schema has been changed since last call
        local uv = self:loadOneRow(
        ---@language SQL
                [[pragma user_version;]])
        if self.SchemaVersion ~= uv.user_version then
            self:flushSchemaCache()
        end

        self.ActionQueue:clear()

        result = ff(self, unpack(args))

        if meta.schemaChange or self.SchemaChanged then
            self.SchemaVersion = (self.SchemaVersion or 0) + 1
            self.db:exec(string.format([[pragma user_version=%d;]], self.SchemaVersion))
        end

        self.ActionQueue:run()

        self.db:exec 'commit'
    end

    local function error_handler(error)
        --errorMsg = tostring(error)
        errorMsg = debug.traceback(tostring(error))
        print(debug.traceback(tostring(error)))
    end

    local ok = xpcall(execute, error_handler)

    if not ok then
        self.db:exec 'rollback'
        ctx:result_error(errorMsg)
    else
        ctx:result(result)
    end

    self:flushDataCache()
    self.AccessControl:flushCache()
end

-- Utility method to obtain prepared sqlite statement
-- All prepared statements are kept in DBContext.Statements pool and accessed by sql as key
--- @param sql string
--- @return userdata @comment sqlite3_stmt
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
        where not exists (select ID from [.sym_names] where [Value] = :v limit 1);
        ]]
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
        self:checkSqlite(stmt:bind_names(params))
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
--- @return function @comment iterator
function DBContext:loadRows(sql, params)
    local stmt = self:getStatement(sql)
    local ok = stmt:bind_names(params)
    if ok ~= 0 then
        self:checkSqlite(ok)
    end

    return stmt:nrows()
end

-- Returns class definition using Classes only (not checking NAMClasses). Used, for example, for loading read-only version of objects
---@param classIdOrName number @comment number or string
---@param mustExist boolean
---@see ClassDef
---@return ClassDef | nil
function DBContext:getClassDefRO(classIdOrName, mustExist)
    ---@type ClassDef
    local result

    -- First, check already loaded classes
    result = self.Classes[classIdOrName]
    if result then
        if type(classIdOrName) == 'string' then
            assert(result.Name.text == classIdOrName, 'result.Name.text == classIdOrName')
        else
            assert(result.ClassID == classIdOrName, string.format('%s == %s', result.ClassID, classIdOrName))
        end
        return result, false
    end

    -- Second, lookup in the database
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
        return nil, false
    end

    result = ClassDef { data = classRow, DBContext = self }
    ClassCollection_add(self.Classes, result)

    return result, false
end

-- Loads class definition (as defined in [.classes] and [flexi_prop] tables)
-- If class is not found and mustExist is true, will throw error
---@param classIdOrName number @comment number or string
---@param mustExist boolean
---@see ClassDef
---@return ClassDef | nil, boolean @comment nil, if not found; true if class was found in NAMClasses
function DBContext:getClassDef(classIdOrName, mustExist)
    ---@type ClassDef
    local result
    -- Check if class is in the list of new-and-modified classes
    if self.NAMClasses ~= nil then
        result = self.NAMClasses[classIdOrName]
        if result then
            return result, true
        end
    end

    result = self:getClassDefRO(classIdOrName, false)
    if result ~= nil then
        return result, false
    end

    if mustExist then
        error(string.format('Class %s not found', classIdOrName))
    end
    return nil, false
end

-- Returns schema definition for entire database, single class, or single property
---@param className string | nil
---@param propertyName string | nil
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

            -- TODO
            cls.toJSON()
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
---@param action string | nil @comment to provide help for specific action
function DBContext:flexi_Help(action)
    local result = { 'Usage:' }

    local function addActionInfo(info)
        if info.actions ~= nil then
            table.insert(result, table.concat(info.actions, ', ') .. ':')
        end
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
--- @param userInfo UserInfo | string
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

--- Locks property mapping for the given class so that no alterations can be made for mapped properties
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

--- Closes all opened statements, flushes cache
function DBContext:flexi_close()
    self:flushSchemaCache()
    self:flushDataCache()
    return 'Schema and data caches were flushed'
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
            return propDef.rules.type == 'inner'
        end)
    end)
end

function DBContext:flushSchemaCache()
    self.Classes = DictCI()
    self.ClassProps = {}
    self.Functions = {}
    self:flushDataCache()
    self:initMemoizeFunctions()
    self:flushCurrentUserCheckPermissions()
    self:finalizeStatements()
    self.events:emit(DBContext.EVENT_NAMES.FLUSH_SCHEMA_DATA, self)
end

function DBContext:flushDataCache()
    self.Objects = {}
end

---@param objectID number
---@return DBObject
function DBContext:getObject(objectID)

    -- TODO Check access permissions for class and specific object

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
---@return userdata @comment lsqlite.stmt
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
---@param params table | nil
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
--- @return function @comment iterator
function DBContext:LoadAdhocRows(sql, params)
    local stmt = self:getAdhocStmt(sql, params)
    return stmt:nrows()
end

-- Internal method to initialize metadata reference (NameRef, PropRef...)
-- Converts source data (container[fieldName] to refClass)
-- Source data can be either table (with id and text fields) or string
-- (will be converted to table with text field)
---@param container table
---@param fieldName string
---@param refClass NameRef
---@return NameRef
function DBContext:InitMetadataRef(container, fieldName, refClass)
    local v = container[fieldName]
    if not v then
        return nil
    end
    if type(v) == 'string' then
        v = { text = v }
    else
        assert(type(v) == 'table')
    end
    v = setmetatable(v, refClass)
    container[fieldName] = v
    return v
end

--[[
Activates/deactivates debugger mode, so that errors and asserts
are automatically switch app to the command line debugging mode
]]
---@param mode string | number @comment ON on 1 OFF off 0
function DBContext:debugger(mode)
    mode = type(mode) == 'string' and string.lower(mode) or mode
    if mode == 'on' or mode == 1 or mode == 'yes' then
        if dbg == nil then
            -- Enable auto_where to make stepping through code easier to follow. This will automatically show 5 lines of code
            -- around the current debugging location
            dbg = require 'debugger'
            dbg.auto_where = 2

            --error = dbg.error
            --assert = dbg.assert
        end

        self.debugMode = true
    elseif mode ~= nil and mode ~= 'off' and mode ~= 'no' and mode ~= 0 then
        error('Expected zero or one parameter with value ON | YES | 1 | OFF | NO | 0')
    else
        self.debugMode = false
        --error = g_error
        --assert = g_assert
    end

    return self.debugMode and 1 or 0
end

--- Sets new ActionQueue. Id actQue is nil, creates new ActionQueue
--- Typical usage is to temporarily replace current queue with a scope-centric one (e.g. create class/schema to allow
--- postponed class or property creation)
---@param actQue ActionQueue | nil
---@return ActionQueue
function DBContext:setActionQueue(actQue)
    if not actQue then
        actQue = ActionQueue(self)
    end
    local result = self.ActionQueue
    self.ActionQueue = actQue
    return result
end

---@param classDef ClassDef
function DBContext:setNAMClass(classDef)
    if self.NAMClasses == nil then
        self.NAMClasses = DictCI()
    end
    ClassCollection_add(self.NAMClasses, classDef)
end

-- Moves all new-and-modified classes to the main class dictionary. Clears NAMClasses at the end
function DBContext:applyNAMClasses()

    local success, errorMsg = pcall(function()
        if self.NAMClasses ~= nil then
            for className, c in pairs(self.NAMClasses) do
                if type(className) == 'string' then
                    ClassCollection_add(self.Classes, c)
                end
            end

            self.NAMClasses = nil
        end
    end)

    if not success then
        error(errorMsg)
    end
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
local flexi_DataUpdate = require 'flexi_DataUpdate'

-- Initialization should be **AFTER** all FLEXI functions are defined
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
    [flexi_DataUpdate.flexi_ImportData] = { shortInfo = '', fullInfo = [[]], schemaChange = true },
    [DBContext.flexi_close] = { shortInfo = '', fullInfo = [[]], schemaChange = false },
    [DBContext.debugger] = { shortInfo = '', fullInfo = [[]], schemaChange = false },
}

-- Dictionary by action names
flexiFuncs = {
    ['schema create'] = flexi_CreateClass.CreateSchema,
    ['create schema'] = flexi_CreateClass.CreateSchema,

    ['create class'] = flexi_CreateClass.CreateClass,
    ['class create'] = flexi_CreateClass.CreateClass,
    ['create'] = flexi_CreateClass.CreateClass,
    ['class'] = flexi_CreateClass.CreateClass,
    ['new class'] = flexi_CreateClass.CreateClass,

    ['alter class'] = flexi_AlterClass,
    ['class alter'] = flexi_AlterClass,
    ['alter'] = flexi_AlterClass,

    ['drop'] = flexi_DropClass,
    ['drop class'] = flexi_DropClass,
    ['class drop'] = flexi_DropClass,
    ['class delete'] = flexi_DropClass,
    ['delete class'] = flexi_DropClass,
    ['delete'] = flexi_DropClass,

    ['create property'] = flexi_CreateProperty,
    ['property create'] = flexi_CreateProperty,
    ['prop create'] = flexi_CreateProperty,
    ['create prop'] = flexi_CreateProperty,
    ['prop'] = flexi_CreateProperty,
    ['property'] = flexi_CreateProperty,
    ['new property'] = flexi_CreateProperty,
    ['new prop'] = flexi_CreateProperty,

    ['alter property'] = flexi_AlterProperty,
    ['property alter'] = flexi_AlterProperty,
    ['prop alter'] = flexi_AlterProperty,
    ['alter prop'] = flexi_AlterProperty,

    ['drop property'] = flexi_DropProperty,
    ['property drop'] = flexi_DropProperty,
    ['prop drop'] = flexi_DropProperty,
    ['drop prop'] = flexi_DropProperty,

    ['configure'] = flexi_Configure,
    ['config'] = flexi_Configure,
    ['initialize'] = flexi_Configure,
    ['init'] = flexi_Configure,

    ['ping'] = DBContext.flexi_ping,
    ['current user'] = DBContext.flexi_CurrentUser,

    ['property to object'] = flexi_PropToObject,
    ['prop to object'] = flexi_PropToObject,

    ['object to property'] = flexi_ObjectToProp,
    ['object to prop'] = flexi_ObjectToProp,

    ['split property'] = flexi_SplitProperty,
    ['split prop'] = flexi_SplitProperty,

    ['merge property'] = flexi_MergeProperty,
    ['merge prop'] = flexi_MergeProperty,

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
    ['new trigger'] = TriggerAPI.Create,
    ['trigger new'] = TriggerAPI.Create,

    ['drop trigger'] = TriggerAPI.Drop,
    ['trigger drop'] = TriggerAPI.Drop,

    ['import data'] = flexi_DataUpdate.flexi_ImportData,
    ['import'] = flexi_DataUpdate.flexi_ImportData,
    ['data import'] = flexi_DataUpdate.flexi_ImportData,
    ['load data'] = flexi_DataUpdate.flexi_ImportData,
    ['load'] = flexi_DataUpdate.flexi_ImportData,

    ['close'] = DBContext.flexi_close,
    ['reset'] = DBContext.flexi_close,
    ['flush'] = DBContext.flexi_close,

    ['debugger'] = DBContext.debugger,
    ['debug'] = DBContext.debugger,


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
