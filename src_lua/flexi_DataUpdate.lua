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
local DBObject = require 'DBObject'
local class = require 'pl.class'
local CreateAnyProperty = require('flexi_CreateProperty').CreateAnyProperty

-- Helper class to save objects to DB
---@class SaveObjectParams
local SaveObjectHelper = class()

-- Ensures that user has required permissions for class level
---@param classDef ClassDef
function SaveObjectHelper:checkClassAccess(classDef, op)
    self.DBContext.ensureCurrentUserAccessForClass(classDef.ClassID, op)
end

-- Ensures that user has required permissions for property level
---@param propDef PropertyDef
function SaveObjectHelper:checkPermissionAccess(propDef, op)
    self.DBContext.ensureCurrentUserAccessForProperty(propDef.PropertyID, op)
end

---@param DBContext DBContext
function SaveObjectHelper:_init(DBContext)
    self.DBContext = DBContext
    self.unresolvedReferences = {}
    self.checkedClasses = {}

    -- Properties already checked for user access permissions
    self.checkedProps = {}
end

function SaveObjectHelper:resolveReferences()

end

-- Saves single object
---@param className string
---@param oldRowID number
---@param newRowID number
---@param data table @comment payload from JSON
function SaveObjectHelper:saveObject(className, oldRowID, newRowID, data)
    local classDef = self:getClassDef(className)
    local obj = oldRowID and self:getObject(oldRowID) or DBObject(self, classDef)

    local op

    if oldRowID then
        if newRowID then
            op = 'U' -- update
        else
            op = 'D' -- delete
        end
    else
        op = 'C' -- insert
    end

    -- Check class level permissions

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

        -- check access rules


        -- if reference property, proceed recursively
        if prop:isReference() then
            if op == 'insert' and (prop.rules.type == 'nested' or prop.rules.type == 'master') then
                -- Sub-data is data
            else
                -- Sub-data is query to return ID(s) to update or delete references
            end
        else
            -- assign scalar value or array of scalar values
        end
    end

    -- validate properties
    -- call custom _before_ trigger (defined in Lua), first for mixin classes (if applicable)
    -- validate data, using dynamically defined schema. If any missing references found, remember them in Lua table

    obj:saveToDB()

    -- call custom _after_ trigger (defined in Lua), first for mixin classes (if applicable), then for *this* class


end

--[[
Implementation of flexi_data virtual table xUpdate API: insert, update, delete
]]

---@param self DBContext
---@param unresolvedRefs table
local function resolveReferences(self, unresolvedRefs)

end

--[[
    CHECK_STMT_PREPARE(
            db,
            "insert into [.range_data] ([ObjectID], [ClassID_1], "
                    "[A0], [_1], [B0], [B1], [C0], [C1], [D0], [D1]) values "
                    "(:1, :2, :2, :3, :4, :5, :6, :7, :8, :9, :10);",
            &pCtx->pStmts[STMT_INS_RTREE]);

    CHECK_STMT_PREPARE(
            db,
            "update [.range_data] set "
                    "[A0] = :3, [A1] = :4, [B0] = :5, [B1] = :6, "
                    "[C0] = :7, [C1] = :8, [D0] = :9, [D1] = :10 where ObjectID = :1;",
            &pCtx->pStmts[STMT_UPD_RTREE]);

    CHECK_STMT_PREPARE(
            db, "delete from [.range_data] where ObjectID = :1;",
            &pCtx->pStmts[STMT_DEL_RTREE]);
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
                        saveHelper:saveObject(clsName, row, nil, nil)
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

return flexi_DataUpdate