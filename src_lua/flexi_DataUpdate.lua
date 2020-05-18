---
--- Created by slanska.
--- DateTime: 2017-11-01 11:27 PM
---

--[[
Saves JSON payload coming from flexi_data virtual table and eponymous table.
Support 3 formats of payload: single object, array of objects and hash of class payloads
Auto creates dynamic property if class has allowAnyProps.
Checks user permissions
Handles reference properties, with nested data or queries to get IDs of referenced objects
Fires custom triggers BEFORE and AFTER save.
Uses DBObject and DBCell Api for data manipulation.
]]

local json = cjson or require('cjson')
local class = require 'pl.class'
local QueryBuilder = require('QueryBuilder').QueryBuilder
local Constants = require 'Constants'
local DictCI = require('Util').DictCI
local SqliteTable = require 'SqliteTable'

--[[
Internal helper class to save objects to DB
]]
---@class SaveObjectHelper
---@field DBContext DBContext
---@field QueryBuilder QueryBuilder
---@field unresolvedReferences table @comment TODO
---@field checkedClasses table @comment TODO
---@field sqliteTables table<string, SqliteTable>

local SaveObjectHelper = class()

---@param DBContext DBContext
function SaveObjectHelper:_init(DBContext)
    self.DBContext = DBContext
    self.QueryBuilder = QueryBuilder(DBContext)
    self.unresolvedReferences = {}
    self.checkedClasses = {}

    -- Properties already checked for user access permissions
    self.checkedProps = {}
end

-- Saves single object
---@param className string
---@param oldRowID number
---@param newRowID number
---@param data table @comment object payload from JSON
function SaveObjectHelper:saveObject(className, oldRowID, newRowID, data)
    local classDef = self.DBContext:getClassDef(className, false)

    if not classDef then
        -- clone parameters to be used in deferred callback
        local params = {}
        params.className = className
        params.oldRowID = oldRowID
        params.newRowID = newRowID
        params.data = data
        -- also add self
        params.self = self

        self.DBContext.ActionQueue:enqueue(function(params)
            -- Flexilite class not found, but this maybe potentially native SQLite table/view
            if not params.self.sqliteTables then
                params.self.sqliteTables = DictCI()
            end
            ---@type SqliteTable
            local sqlTbl = params.self.sqliteTables[params.className]
            if not sqlTbl then
                sqlTbl = SqliteTable(params.self.DBContext, params.className)
                params.self.sqliteTables[params.className:lower()] = sqlTbl
            end

            if not params.oldRowID then
                -- Insert new record
                sqlTbl:insert(params.data)
            else
                local where
                if params.newRowID then
                    --TODO set where
                    sqlTbl:update(params.data, where)
                else
                    sqlTbl:delete(where)
                end
            end
        end, params)
    else
        ---@type DBObject
        local obj

        local op = not oldRowID and Constants.OPERATION.CREATE or (newRowID and Constants.OPERATION.UPDATE
                or Constants.OPERATION.DELETE)
        if op == Constants.OPERATION.CREATE then
            obj = self.DBContext:NewObject(classDef, data)
        elseif op == Constants.OPERATION.UPDATE then
            obj = self.DBContext:EditObject(oldRowID)
            if oldRowID ~= newRowID then
                obj.ID = newRowID
            end
        else
            obj = self.DBContext:EditObject(oldRowID)
            obj.ID = 0
        end

        obj:saveToDB()
    end
end

---@param self DBContext
---@param className string
--- (optional) if not specified, must be defined in JSON payload
---@param oldRowID number
--- if null, it is insert operation
---@param newRowID number
--- if null and oldRowID not null, it is delete.
--- if not null and oldRowID is not null, this is update. If different - it is ID change
--- if not null and oldRowID is null, this is insert
---@param data table
--- data payload. Can be single object or array of objects. If className is not set,
---payload should be object, with className as keys
---Examples: 1) single object, className is not null - {"Field1": "String", "Field2": 123...}
---2) array of objects, class is not null - [{"Field1": "String", "Field2": 123...}, {"Field1": "String2", "Field2": 123...}]
---2) class is null - {"Class1": [{"Field1": "String", "Field2": 123...}, {"Field1": "String2", "Field2": 123...}]...}
---@param queryJSON string
--- filter to apply - optional, for update and delete
local function _dataUpdate(self, className, oldRowID, newRowID, data, queryJSON)
    local saveHelper = SaveObjectHelper(self)
    local isArray = #data > 0
    if className then
        -- Basic (classic) mode
        if isArray then
            if oldRowID or newRowID then
                error('Incompatible arguments: oldRowID and newRowID must be null for array mode')
            end

            for _, row in ipairs(data) do
                saveHelper:saveObject(className, row, nil, nil)
            end
        else
            -- xUpdate mode: single object with row IDs
            saveHelper:saveObject(className, data, oldRowID, newRowID)
        end
    else
        -- Extended (classless) mode
        if newRowID then
            error('Invalid arguments: newRowID must be null if className is not passed')
        end

        if isArray then
            error('Invalid arguments: data cannot be array')
        end

        if oldRowID then
            local oldObj = self.getObject(oldRowID)
            if not oldObj then
                error(string.format('Object with id %d not found', oldRowID))
            end
            oldObj:loadFromDB()
            saveHelper:saveObject(oldObj.ClassDef.Name.text, data, oldRowID, nil)
        else
            for clsName, dd in pairs(data) do
                if #dd > 0 then
                    for _, row in ipairs(dd) do
                        saveHelper:saveObject(clsName, nil, nil, row)
                    end
                else
                    -- TODO Load objects based on query
                    local query = json.decode(queryJSON)

                    saveHelper:saveObject(self, clsName, dd, nil, nil)
                end
            end
        end
    end

    -- resolve pending references
    self.ActionQueue:run()
end

--[[
Implementation of flexi_data virtual table xUpdate API: insert, update, delete
]]

--[[
 Inserts/updates/deletes data. Supports classic and classless mode, which are distinguished by className
 If className is not null, this is classic (basic) mode. Otherwise, this is classless (extended) mode.
 In classic mode, if dataJSON is single object, oldRowID and newRowID are treated like in xUpdate
 function in SQLite virtual table API (see notes below). If dataJSON is array, it is insert operation,
 and both oldRowID and newRowID  must be null
 In classless mode, className is null and newRowID must be null too.
 oldRowID (but not newRowID) can be still passed, so that class will be determined from object ID.
 if all className, oldRowID and newRowID are null, this is a pure extended mode.
 In this mode, if both queryJSON and dataJSON are not null, this is update. dataJSON must be single object
 If queryJSON is null, dataJSON may not be null, and this is insert mode. dataJSON can be single object, array or object hash with class names
 If queryJSON is not null and dataJSON is null, this is delete, based on queryJSON.
 If both dataJSON and queryJSON are null, error is thrown.

 When called from virtual table xUpdate, it will be variant of basic mode (single object only, className, oldRowID and newRowID)
 ]]
---@param self DBContext
---@param className string
--- (optional) if not specified, must be defined in JSON payload
---@param oldRowID number | string
--- if null, it is insert operation
---@param newRowID number | string
--- if null and oldRowID not null, it is delete.
--- if not null and oldRowID is not null, this is update. If different - it is ID change
--- if not null and oldRowID is null, this is insert
---@param dataJSON string
--- data payload. Can be single object or array of objects. If className is not set,
---payload should be object, with className as keys
---Examples: 1) single object, className is not null - {"Field1": "String", "Field2": 123...}
---2) array of objects, class is not null - [{"Field1": "String", "Field2": 123...}, {"Field1": "String2", "Field2": 123...}]
---2) class is null - {"Class1": [{"Field1": "String", "Field2": 123...}, {"Field1": "String2", "Field2": 123...}]...}
---@param queryJSON string
--- filter to apply - optional, for update and delete
local function flexi_DataUpdate(self, className, oldRowID, newRowID, dataJSON, queryJSON)
    local data = json.decode(dataJSON)

    if type(data) ~= 'table' then
        error('Invalid data type')
    end

    -- Check if oldRowID and/or newRowID are encoded objects

    if queryJSON and (oldRowID or newRowID) then
        error('Incompatible arguments: queryJSON cannot be used with oldRowID and newRowID')
    end

    --[[
    Data update function was initially developed to be compatible with SQLite virtual table xUpdate API, which
    operates with integers only for row ID.
    In order to accomplish other use cases flexi_DataUpdate also supports multi key primary keys.
    This is implemented using the following logic:
    - if not nil, types of both newRowID and oldRowID must be the same - either number os string (nils are treated as omitted ID)
    - if type is number, it is treated as row ID (the same as original xUpdate API)
    - if type is string, it is parsed as JSON payload. Result of parsing can be one of those: number (again, treated as
    row ID); table - treated as key-value dictionary where key is property name, and value - ID value; array - values
    are treated differently for updatable view and normal table. For table, ordinal positions of values are layed out with primary key
    definition as supplied by SQLite pragma table_info. For updatable view (which is mostly many-to-many relation) these numbers are
    used based on column ordinal position (also, as per result of SQLite pragma table_info)
    ]]
    if type(oldRowID) == 'string' then
        oldRowID = json.decode(oldRowID)
        assert(type(newRowID) == 'string' or type(newRowID) == 'nil', 'flexi_DataUpdate: both newRowID and oldRowID must be the same type')
    end

    if type(newRowID) == 'string' then
        newRowID = json.decode(newRowID)
        assert(type(oldRowID) == 'string' or type(oldRowID) == 'nil', 'flexi_DataUpdate: both newRowID and oldRowID must be the same type')
    end

    local savedActQue = self.ActionQueue == nil and self:setActionQueue() or self.ActionQueue
    local result, errMsg = pcall(_dataUpdate, self, className, oldRowID, newRowID, data, queryJSON)

    if savedActQue ~= nil then
        self:setActionQueue(savedActQue)
    end

    if not result then
        error(errMsg)
    end
end

-- flexi('import data', 'data-as-json')
---@param self DBContext
---@param jsonString string
local function ImportData(self, jsonString)
    local result = flexi_DataUpdate(self, nil, nil, nil, jsonString, nil)
    return result
end

return { flexi_DataUpdate = flexi_DataUpdate, flexi_ImportData = ImportData }
