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

local json = require('cjson')
local class = require 'pl.class'
local schema = require 'schema'
local tablex = require 'pl.tablex'
local CreateAnyProperty = require('flexi_CreateProperty').CreateAnyProperty
local QueryBuilder = require 'QueryBuilder'

--[[
Internal helper class to save objects to DB
]]
---@class SaveObjectParams
---@field DBContext DBContext
---@field QueryBuilder QueryBuilder
---@field unresolvedReferences table @comment TODO
---@field checkedClasses table @comment TODO

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

-- Ensures that user has required permissions for class level
---@param classDef ClassDef
---@param op string @comment 'C' or 'U' or 'D'
function SaveObjectHelper:checkClassAccess(classDef, op)
    self.DBContext.ensureCurrentUserAccessForClass(classDef.ClassID, op)
end

-- Ensures that user has required permissions for property level
---@param propDef PropertyDef
---@param op string @comment 'C' or 'U' or 'D'
function SaveObjectHelper:checkPermissionAccess(propDef, op)
    self.DBContext.ensureCurrentUserAccessForProperty(propDef.PropertyID, op)
end

function SaveObjectHelper:resolveReferences()
    for _, item in ipairs(self.unresolvedReferences) do
        -- item: {propDef, object}

        -- run query
        -- TODO Use iterator
        local refIDs = self.QueryBuilder:GetReferencedObjects(item.propDef, item.object[item.propDef.Name.text])
        for idx, refID in ipairs(refIDs) do
            -- PropIndex =  idx - 1
        end
    end
end

---@param classDef ClassDef
---@param data table
function SaveObjectHelper:checkCreateAdHocProperties(classDef, data)
    for name, value in pairs(data) do
        local prop = classDef:hasProperty(name)

        if not prop then
            if classDef.D.allowAnyProps then
                -- auto create new property
                prop = CreateAnyProperty(self, classDef, name)
            else
                error(string.format('Property [%s] is not found or ambiguous', name))
            end
        end
    end
end

---@param classDef ClassDef
---@param data table
function SaveObjectHelper:processReferenceProperties(classDef, data)
    for name, value in pairs(data) do
        local prop = classDef:hasProperty(name)
        -- if reference property, proceed recursively
        if prop:isReference() then
            if prop.rules.type == 'nested' or prop.rules.type == 'master' then
                -- Sub-data is data
            else
                -- Sub-data is query to return ID(s) to update or delete references
            end
        else
            -- assign scalar value or array of scalar values
        end
    end
end

---@param classDef ClassDef
---@param data table
function SaveObjectHelper:validateObjectData()
    if op == 'C' or op == 'U' then
        local objSchema = classDef:getObjectSchema(op)
        if objSchema then
            local err = schema.CheckSchema(data, objSchema)
            if err then
                -- TODO 'Invalid input data:'
                error(err)
            end
        end
    end
end

---@param classDef ClassDef
---@param data table
---@param obj DBObject
function SaveObjectHelper:saveNestedObjects(classDef, data, obj)
    for _, propDef in ipairs(self.DBContext.GetNestedAndMasterProperties(classDef.ClassID)) do
        local dd = obj[propDef.Name.text]
        if dd and type(dd) == 'table' then
            dd['$master'] = obj.ID
            self:saveObject(propDef.refDef.classRef.text, nil, nil, dd)
        end
    end
end

---@param classDef ClassDef
---@param data table
---@param obj DBObject
---@param op string @comment 'C', 'U', 'D'
function SaveObjectHelper:setDefaultData(classDef, data, obj, op)
    if op == 'C' then
        for propName, propDef in pairs(classDef.Properties) do
            local dd = propDef.D.defaultValue
            if data[propName] == nil and dd ~= nil then
                if type(dd) == 'table' then
                    data[propName] = tablex.deepcopy(dd)
                else
                    data[propName] = dd
                end
            end
        end
    end
end

function SaveObjectHelper:fireBeforeTrigger()
    -- TODO call custom _before_ trigger (defined in Lua), first for mixin classes (if applicable)

end

function SaveObjectHelper:fireAfterTrigger()
    -- TODO call custom _after_ trigger (defined in Lua), first for mixin classes (if applicable), then for *this* class

end

-- Saves single object
---@param className string
---@param oldRowID number
---@param newRowID number
---@param data table @comment object payload from JSON
function SaveObjectHelper:saveObject(className, oldRowID, newRowID, data)
    local classDef = self.DBContext:getClassDef(className)

    -- TODO Check class level permissions

    -- Check if new ad-hoc properties need to be created
    self:checkCreateAdHocProperties(classDef, data)

    -- DBObject
    local obj = oldRowID and self.DBContext:getObject(oldRowID) or self.DBContext:NewObject(classDef, data)

    local op = not oldRowID and 'C' or (newRowID and 'U' or 'D')

    -- TODO check access rules

    self:processReferenceProperties(classDef, data)

    -- for new object set default data
    self:setDefaultData(classDef, data, obj, op)

    -- before trigger
    self:fireBeforeTrigger()

    -- validate data, using dynamically defined schema. If any missing references found, remember them in Lua table
    self:validateObjectData(classDef, data)

    -- will save scalar values only
    obj:saveToDB()

    -- Save nested/child objects
    self:saveNestedObjects(classDef, data)

    for _, propDef in ipairs(self.DBContext.GetClassReferenceProperties(classDef.ClassID)) do
        -- Treat property value as query to get list of objects
        table.insert(self.unresolvedReferences, { propDef = propDef, object = obj })
    end

    self:fireAfterTrigger()
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
---@param oldRowID number
--- if null, it is insert operation
---@param newRowID number
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

    local isArray = #data > 0
    if queryJSON and (oldRowID or newRowID) then
        error('Incompatible arguments: queryJSON cannot be used with oldRowID and newRowID')
    end

    local saveHelper = SaveObjectHelper(self)

    if className then
        -- Basic (classic) mode
        if isArray then
            if oldRowID or newRowID then
                error('Incompatible arguments: oldRowID and newRowID must be null for array mode')
            end

            for i, row in ipairs(data) do
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
                    for i, row in ipairs(dd) do
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

    saveHelper:resolveReferences()
end

-- flexi('import data', 'data-as-json')
---@param self DBContext
---@param jsonString string
local function ImportData(self, jsonString)
    local result = flexi_DataUpdate(self, nil, nil, nil, jsonString, nil)
    return result
end

return { flexi_DataUpdate = flexi_DataUpdate, flexi_ImportData = ImportData }