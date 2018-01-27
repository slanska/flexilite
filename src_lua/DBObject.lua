---
--- Created by slanska.
--- DateTime: 2017-12-19 7:12 AM
---

--[[
Internally used facade to [.object] row.
Provides access to property values, saving in database etc.
This is low level data operations
Holds collection of DBProperty

Handles access rules, nested objects, boxed access to object's properties, updating range_data and multi_key indexes

DBObject
    - Boxed() - BoxedDBObject to be accessed in custom scripts
    - props - collection of DBProperty by property name
        - Boxed() - BoxedDBProperty
        - values - array of DBValue
            - BoxedDBValue - protected value to be accessed in custom scripts

Main features:
SetData
GetData
new and existing object ID
data validation
access rules on class/object/permission level
loading data from db
saving data to db
boxed data (user access)
access by property name and index
]]

local class = require 'pl.class'
local bits = type(jit) == 'table' and require('bit') or require('bit32')
local DBValue = require 'DBValue'
local tablex = require 'pl.tablex'
local JSON = require 'cjson'
local Util64 = require 'Util'
local Constants = require 'Constants'
local schema = require 'schema'
local CreateAnyProperty = require('flexi_CreateProperty').CreateAnyProperty

--[[]]
---@class DBObjectCtorParams
-- [[ID is required, either ClassDef or DBContext are required, other params are optional.
-- DBObject does not manage DBContext.Objects or CUObjects. It behaves as standalone entity.

---@field ClassDef ClassDef
---@field DBContext DBContext
---@field ID number @comment > 0 - existing object, < 0 - new not yet saved object, 0 - object to be deleted
---@field PropIDs table @comment array of integers
---@field Data table

---@class ObjectMetadata
---@field format table <number, table>


---@class DBObject
---@field ID number @comment > 0 - existing object, < 0 - new not yet saved object, 0 - object to be deleted
---@field ClassDef ClassDef
---@field props table <string, DBProperty>
---@field old DBObject @comment not null for edited or deleted objects
---@field ctlo number
---@field MetaData ObjectMetadata
local DBObject = class()

-- DBObject constructor.
---@param params DBObjectCtorParams
function DBObject:_init(params)
    self.ID = assert(params.ID)

    if self.ID > 0 then
        -- Existing object
        assert(params.DBContext or params.ClassDef, 'Either ClassDef or DBContext are required')
        local DBContext = params.DBContext or params.ClassDef.DBContext
        self:loadObjectRow(DBContext)
        if params.PropIDs then
            self:loadFromDB(params.PropIDs)
        end
    else
        -- New object
        self.ClassDef = assert(params.ClassDef)
        -- TODO initialize new object
        -- ctlo
    end

    self.props = {}

    if params.Data then
        self:SetData(params.Data)
    end
end

-- Loads row from .objects table. Updates ClassDef if previous ClassDef is null or does not match actual definition
---@param DBContext DBContext
function DBObject:loadObjectRow(DBContext)
    -- Load from .objects
    local obj = DBContext:loadOneRow([[select * from [.objects] where ObjectID=:ObjectID;]], { ObjectID = self.ID })

    -- Theoretically, object ID may not match class def passed in constructor
    if not self.ClassDef or obj.ClassID ~= self.ClassDef.ClassID then
        self.ClassDef = self.ClassDef.DBContext:getClassDef(obj.ClassID)
    end

    if obj.MetaData then
        -- object MetaData may include: accessRules, colMapMetaData and other elements
        self.MetaData = JSON.decode(obj.MetaData)
        -- TODO further processing
    else
        self.MetaData = nil
    end

    self.ctlo = obj.ctlo

    -- Set values from mapped columns
    if self.ClassDef.ColMapActive then
        for col, prop in pairs(self.ClassDef.propColMap) do
            -- Build ctlv
            local ctlv = 0
            --col:byte() -string.byte('A')

            -- Extract cell MetaData
            local colMetaData = self.MetaData and self.MetaData.colMapMetaData and self.MetaData.colMapMetaData[prop.PropertyID]
            local cell = DBValue { Object = self, Property = prop, PropIndex = 1, Value = obj[col], ctlv = ctlv, MetaData = colMetaData }
            -- TODO
            --self.props[prop.Name.text] = self.props[prop.PropertyID] or {}
            --self.props[prop.PropertyID][1] = cell
        end
    end
end

-- Provides access to object data from custom scripts and triggers. Hides all internals
---@return BoxedDBObject
function DBObject:Boxed()
    if not self.boxed then
        self.boxed = setmetatable({}, {
        -- Get property
            __index = function(propName)
                return self:getDBProperty(propName)
            end,

        -- Set property value
            __newindex = function(propName, propValue)
                return self:setDBProperty(propName, propValue)
            end,

        -- No access to internals
            __metatable = nil,
        })
    end

    return self.boxed
end

-- Gets DBProperty by name. For C and U operations may create a new property, if class has allowAnyProps
---@param propName string
---@param op string @comment 'C', 'R', 'U', 'D'
---@return DBProperty
function DBObject:getDBProperty(propName, op)
    local result = self.props[propName]
    if not result then
        -- check original
        if self.old then
            local oldObj = self.ClassDef.Objects[self.ID]
            result = oldObj:getDBProperty(propName)
        else
            -- This is original. Property may be not loaded yet
            local propDef = self.ClassDef:hasProperty(propName)
            -- TODO Check prop permissions
            if not propDef and (op == 'C' or op == 'U') and self.ClassDef.allowAnyProps then
                    propDef = CreateAnyProperty(self.ClassDef.DBContext, self.ClassDef, propName)
            end
            assert(propDef, string.format('Property %s not found', propName))
            result = propDef:CreateDBProperty(self)
            self.props[propName] = result
        end
    end

    return result
end

---@param propName string
---@param propValue any
---@return any @comment result from DBProperty:SetValue
function DBObject:setDBProperty(propName, propValue)
    local prop = self:getDBProperty(propName, 'U')
    return prop:SetValue(1, propValue)
end

-- Sets entire object data, including child objects
-- and links (using queries).
-- Object must be in 'C' or 'U' state
---@param data table
function DBObject:SetData(data)
    if not data then
        return
    end
    local op = assert(self:getOpCode(), 'Object must be in edit or insert mode')

    for propName, propValue in pairs(data) do
        self:setDBProperty(propName, propValue)
    end
end

-- Builds table with all non null property values
-- Includes detail objects. Does not include links
---@param excludeDefault boolean
function DBObject:GetData(excludeDefault)
    local result = {}
    for propName, propDef in pairs(self.ClassDef.Properties) do
        local pp = self:getDBProperty(propName)
        result[propName] = tablex.deepcopy(pp:GetValue())
    end

    for propName, propList in pairs(self.ClassDef.MixinProperties) do
        if #propList == 1 and not self.ClassDef.Properties[propName] then
            -- Process properties in mixin classes only if there is no conflict
        else
            -- Other mixin properties are processed as 'nested' objects
        end
    end
    return result
end


function DBObject:setMappedPropertyValue(prop, value)
    -- TODO
end

-- Apply values of mapped columns, if class is set to use column mapping
---@param params table
function DBObject:applyMappedColumns(params)
    if self.ClassDef.ColMapActive then
        for col, prop in pairs(self.ClassDef.propColMap) do
            local cell = self:getRefValue(prop.PropertyID, 1)
            if cell then
                -- update vtypes
                params[col] = cell.Value
            else
                params[col] = nil
            end
        end
    end
end

function DBObject:getParamsForSaveFullText(params)
    if not (self.ClassDef.fullTextIndexing and tablex.size(self.ClassDef.fullTextIndexing) > 0) then
        return false
    end

    params.ClassID = self.ClassDef.ClassID
    params.docid = self.ID

    for key, propRef in pairs(self.ClassDef.fullTextIndexing) do
        local cell = self:getRefValue(propRef.id, 1)
        if cell then
            local v = cell.Value
            -- TODO Check type and value?
            if type(v) == 'string' then
                params[key] = v
            end
        end
    end

    return true
end

function DBObject:getParamsForSaveRangeIndex(params)
    if not (self.ClassDef.rangeIndex and tablex.size(self.ClassDef.rangeIndex) > 0) then
        return false
    end

    params.ObjectID = self.ID

    -- TODO check if all values are not null
    for key, propRef in pairs(self.ClassDef.rangeIndex) do
        local cell = self:getRefValue(propRef.id, 1)
        params[key] = cell.Value
    end

    return true
end

-- SQL for updating multi-key indexes
local multiKeyIndexSQL = {
    C = {
        [2] = [[insert into [.multi_key2] (ObjectID, ClassID, Z1, Z2)
        values (:ObjectID, :ClassID, :1, :2);]],
        [3] = [[insert into [.multi_key3] (ObjectID, ClassID, Z1, Z2, Z3)
        values (:ObjectID, :ClassID, :1, :2, :3);]],
        [4] = [[insert into [.multi_key4] (ObjectID, ClassID, Z1, Z2, Z3, Z4)
        values (:ObjectID, :ClassID, :1, :2, :3, :4);]],
    },
    U = {
        [2] = [[update [.multi_key2] set ClassID = :ClassID, Z1 = :1, Z2 = :2 where ObjectID = :ObjectID;]],
        [3] = [[update [.multi_key3] set ClassID = :ClassID, Z1 = :1, Z2 = :2, Z3 = :3 where ObjectID = :ObjectID;]],
        [4] = [[update [.multi_key4] set ClassID = :ClassID, Z1 = :1, Z2 = :2, Z3 = :3, Z4 = :4 where ObjectID = :ObjectID;]],
    },
-- Extended version of update when ObjectID also gets changed
    UX = {
        [2] = [[update [.multi_key2] set ClassID = :ClassID, Z1 = :1, Z2 = :2, ObjectID = :NewObjectID where ObjectID = :ObjectID;]],
        [3] = [[update [.multi_key3] set ClassID = :ClassID, Z1 = :1, Z2 = :2, Z3 = :3, ObjectID = :NewObjectID where ObjectID = :ObjectID;]],
        [4] = [[update [.multi_key4] set ClassID = :ClassID, Z1 = :1, Z2 = :2, Z3 = :3, Z4 = :4, ObjectID = :NewObjectID where ObjectID = :ObjectID;]],
    },
    D = {
        [2] = [[delete from [.multi_key2] where ObjectID = :ObjectID;]],
        [3] = [[delete from [.multi_key3] where ObjectID = :ObjectID;]],
        [4] = [[delete from [.multi_key4] where ObjectID = :ObjectID;]]
    }
}

---@param op string @comment 'C', 'U', or 'D'
function DBObject:saveMultiKeyIndexes(op)
    if op == 'U' or op == 'D' then
        assert(self.old)
    end

    local function save()
        if op == 'D' then
            local sql = multiKeyIndexSQL[op] and multiKeyIndexSQL[op][keyCnt]
            self.ClassDef.DBContext:execStatement(sql, { ObjectID = self.old.ID })
        else
            for idxName, idxDef in pairs(self.ClassDef.indexes) do
                local keyCnt = #idxDef.properties
                if idxDef.type == 'unique' and keyCnt > 1 then
                    -- Multi key unique index detected

                    local p = { ObjectID = self.ID, ClassID = self.ClassDef.ClassID }
                    for i, propRef in ipairs(idxDef.properties) do
                        local cell = self:getRefValue(propRef.id, 1)
                        if cell and cell.Value then
                            p[i] = cell.Value
                        end
                    end

                    if op == 'U' and self.ID ~= self.old.ID then
                        op = 'UX'
                        p.NewObjectID = self.ID
                        p.ObjectID = self.old.ID
                    end

                    local sql = multiKeyIndexSQL[op] and multiKeyIndexSQL[op][keyCnt]
                    if not sql then
                        error('Invalid multi-key index update specification')
                    end

                    self.ClassDef.DBContext:execStatement(sql, p)
                end
            end
        end
    end

    save()

    -- TODO multi key - use pcall to catch error
    --local ok = xpcall(save,
    --                  function(error)
    --                      local errorMsg = tostring(error)
    --                      -- TODO debug only
    --                      print(debug.traceback(tostring(error)))
    --
    --                      error(string.format('Error updating multikey unique index: %d', errorMsg))
    --                  end)
end

function DBObject:saveToDB()
    local op = self:getOpCode()

    -- before trigger
    self:fireBeforeTrigger()

    if op == 'C' then
        self:setDefaultData()
    end

    self:ValidateData()

    self:processReferenceProperties()

    -- set ctlo
    local ctlo = self.ClassDef.ctlo
    if self.MetaData then
        if self.MetaData.accessRules then
            ctlo = Util64.BOr64(ctlo, Constants.CTLO_FLAGS.HAS_ACCESS_RULES)
        end

        if self.MetaData.formulas then
            ctlo = Util64.BOr64(ctlo, Constants.CTLO_FLAGS.HAS_FORMULAS)
        end

        if self.MetaData.colMetaData then
            ctlo = Util64.BOr64(ctlo, Constants.CTLO_FLAGS.HAS_COL_META_DATA)
        end
    end

    local params = { ClassID = self.ClassDef.ClassID, ctlo = ctlo, vtypes = self.ClassDef.vtypes,
                     MetaData = JSON.encode( self.MetaData ) }

    self:applyMappedColumns(params)

    if op == 'C' then
        -- New object
        self.ClassDef.DBObject:execStatement([[insert into [.objects] (ClassID, ctlo, vtypes,
        A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, MetaData) values (
        :ClassID, :ctlo, :vtypes, :A, :B, :C, :D, :E, :F, :G, :H, :I, :J, :J, :K, :L, :M, :N, :O, :P);]],
                                             params)
        self.ID = self.ClassDef.DBContext.db:last_insert_rowid()

        self.ClassDef.DBContext.Objects[self.NewID] = nil
        self.ClassDef.DBContext.Objects[self.ID] = self

        -- TODO Fix referenced
        self.NewID = nil

        -- Save multi-key index if applicable
        self:saveMultiKeyIndexes('C')

        -- Save full text index, if applicable
        local fts = {}
        if self:getParamsForSaveFullText(ftd) then
            self.ClassDef.DBContext:execStatement([[
            insert into [.full_text_data] (docid, ClassID, X1, X2, X3, X4, X5)
            values (:docid, :ClassID, :X1, :X2, :X3, :X4, :X5);
            ]], fts)
        end

        -- Save rtree if applicable
        local rangeParams = {}
        if self:getParamsForSaveRangeIndex(rangeParams) then
            local sql = string.format([[insert into [.range_data_%d]
                (ObjectID, [A0], [A1],  [B0], [B1],  [C0], [C1],  [D0], [D1], [E0], [E1]) values
                (:ObjectID, :A0, :A1, :B0, :B1, :C0, :C1, :D0, :D1, :E0, :E1);]], self.ClassDef.ClassID)
            self.ClassDef.DBContext:execStatement(sql, rangeParams)
        end
    elseif op == 'U' then
        -- Existing object
        params.ID = self.ID
        self.ClassDef.DBContext:execStatement([[update [.objects] set ClassID=:ClassID, ctlv=:ctlv,
         vtypes=:vtypes, A=:A, B=:B, C=:C, D=:D, E=:E, F=:F, G=:G, H=:H, J=:J, K=:K, L=:L,
         M=:M, N=:N, O=:O, P=:P, MetaData=:MetaData where ObjectID = :ID]], params)

        -- Save multi-key index if applicable
        self:saveMultiKeyIndexes('U')

        -- Save full text index, if applicable
        local fts = {}
        if self:getParamsForSaveFullText(fts) then
            self.ClassDef.DBContext:execStatement([[
            update [.full_text_data] set ClassID = :ClassID, X1 = :X1, X2 = :X2, X3 = :X3, X4 = :X4, X5 = :X5
                where docid = :docid;]], fts)
        end

        -- Save rtree if applicable
        local rangeParams = {}
        if self:getParamsForSaveRangeIndex(rangeParams) then
            local sql = string.format([[update [.range_data_%d] set
                [A0] = :A0, [A1] = :A1,  [B0] = :B0, [B1]= :B1,  [C0] =:C0,
                [C1] = :C1,  [D0] =:D0, [D1] = :D1, [E0] = :E0, [E1] = :E1
                where ObjectID = :ObjectID;]], self.ClassDef.ClassID)
            self.ClassDef.DBContext:execStatement(sql, rangeParams)
        end
    else
        -- 'D'
        assert(self.old)
        local sql = [[delete from [.objects] where ObjectID = :ObjectID;]]
        local args = { ObjectID = self.old.ID }
        self.ClassDef.DBContext:execStatement(sql, args)

        sql = [[delete from [.ref-values] where ObjectID = :ID]]
        self.ClassDef.DBContext:execStatement(sql, args)

        sql = string.format([[delete from [.range_data_%d] were ObjectID = :ObjectID;]], self.ClassDef.ClassID)
        self.ClassDef.DBContext:execStatement(sql, args)

        self:saveMultiKeyIndexes('D')
    end

    -- TODO Save .change_log

    -- Save .ref-values, except references (those will be deferred until all objects in the current batch are saved)
    for i, cell in ipairs(self.props) do
        if not cell:IsLink() then
            cell:saveToDB()
        else
            -- TODO store references in deferred list ??

        end
    end

    -- Save nested/child objects
    self:saveNestedObjects()

    -- After trigger
    self:fireAfterTrigger()

end

--[[ Ensures that all values with PropIndex == 1 and all vector values for properties in the propList are loaded
This is required for updating object. propList is usually determined by list of properties to be updated or to be returned by query
]]
---@param propList table @comment (optional) list of PropertyDef
function DBObject:loadFromDB(propList)
    local sql

    self:loadObjectRow()

    -- TODO Optimize: check if .ref-values need to be loaded whatsoever
    -- tables.difference(ClassDef.Properties, propColMap)

    local params = { ObjectID = self.ObjectID }
    if propList then
        params.PropIDs = JSON.encode(tablex.map(function(prop)
            return prop.PropertyID
        end, propList))

        sql = [[select PropertyID, PropIndex, [Value], ctlv, MetaData
            from [.ref-values] where ObjectID=:ObjectID and (PropIndex=1 or PropertyID in (select [value] from json_each(:PropIDs)));]]
    else
        sql = [[select PropertyID, PropIndex, [Value], ctlv, MetaData
            from [.ref-values] where ObjectID=:ObjectID and PropIndex=1;]]
    end

    for row in self.ClassDef.DBContext:loadRows(sql, params) do
        -- Skip already loaded mapped columns
        if not self.props[row.PropertyID][row.PropIndex] then
            row.Object = self
            row.Property = self.ClassDef.DBContext.ClassProps[row.PropertyID]
            local cell = DBValue(row)
            self.props[row.PropertyID] = self.props[row.PropertyID] or {}
            self.props[row.PropertyID][row.PropIndex] = cell
        end
    end
end

function DBObject:ValidateData()
    local data = self:GetData()
    local op = self:getOpCode()
    if op == 'C' or op == 'U' then
        local objSchema = self.ClassDef:getObjectSchema(op)
        if objSchema then
            local err = schema.CheckSchema(data, objSchema)
            if err then
                -- TODO 'Invalid input data:'
                error(err)
            end
        end
    end
end

function DBObject:CloneForEdit()
    assert(self.ID > 0 and not self.old, 'Cannot clone already cloned or new object')
    -- pass -1 to avoid loading from database
    local result = DBObject { ID = -1, ClassDef = self.ClassDef }
    result.ID = self.ID
    result.old = self
    return result
end

function DBObject:LoadAllValues()
    -- TODO
end

function DBObject:IsNew()
    return self.ID < 0
end

-- Ensures that user has required permissions for class level
---@param classDef ClassDef
---@param op string @comment 'C' or 'U' or 'D'
function DBObject:checkClassAccess(classDef, op)
    self.DBContext.ensureCurrentUserAccessForClass(classDef.ClassID, op)
end

-- Ensures that user has required permissions for property level
---@param propDef PropertyDef
---@param op string @comment 'C' or 'U' or 'D'
function DBObject:checkPermissionAccess(propDef, op)
    self.DBContext.ensureCurrentUserAccessForProperty(propDef.PropertyID, op)
end

function DBObject:resolveReferences()
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
function DBObject:processReferenceProperties(classDef, data)
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

---@param data table
function DBObject:saveNestedObjects(data)
    for _, propDef in ipairs(self.ClassDef.DBContext.GetNestedAndMasterProperties(self.ClassDef.ClassID)) do
        local dd = data[propDef.Name.text]
        if dd and type(dd) == 'table' then
            dd['$master'] = self.ID
            -- TODO Init tested object
            --self:saveToDB(propDef.refDef.classRef.text, nil, nil, dd)
        end
    end
end

---@param data table
function DBObject:setDefaultData()
    local op = self:getOpCode()
    if op == 'C' then
        for propName, propDef in pairs(self.ClassDef.Properties) do
            local dd = propDef.D.defaultValue
            if dd ~= nil then
                local pp = self:getDBProperty(propName, op)
                local vv = pp:GetValue()
                if vv == nil then
                    pp:SetValue(1, tablex.deepcopy(dd))
                end
            end
        end
    end
end

function DBObject:fireBeforeTrigger()
    -- TODO call custom _before_ trigger (defined in Lua), first for mixin classes (if applicable)

end

function DBObject:fireAfterTrigger()
    -- TODO call custom _after_ trigger (defined in Lua), first for mixin classes (if applicable), then for *this* class

end

---@return string @comment 'C', 'U', 'D', based on ID value
function DBObject:getOpCode()
    return self.ID == 0 and 'D' or (self.ID < 0 and 'C' or 'U')
end

return DBObject