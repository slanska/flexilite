---
--- Created by slanska.
--- DateTime: 2017-12-19 7:12 AM
---

--[[
Internally used facade to [.object] row.
Provides access to property values, saving in database etc.
This is low level data operations

Handles access rules, nested objects, boxed access to object's properties, updating range_data and multi_key indexes
Instances of DBObject are kept by DBContext in Objects collection.

There are few helper classes implemented:

DBObject - central object, which support data loading, editing, saving and property access.
Has Boxed() method to access boxed version of current and original versions of data.
Their internal counterparts are curVer and origVer, which are instances of BaseDBOBV and its descendants
Has state field - one of the following value - 'C', 'R', 'U', 'D'


'R': object loaded from database and not yet modified.
curVer is set to WritableDBObject which may redirect property access calls to original()
origVer is set to ReadOnlyDBObject. Write operations raise error
Created by DBContext:LoadObject(ID, forUpdate = false). Also, this is state after saving changes to database

'C': object is newly created and not saved yet.
origVer - VoidDBOV - any property access will raise error
curVer - WritableDBOV - object allows read and write
Create by DBContext:CreateNew(classDef)
After saving origVer is set to ReadOnlyDBOBV with props from curVer, curVer is assigned to new empty WritableDBOV

'U': object is in edit state and not saved yet
origVer - ReadOnlyDBOV, as in 'R'
curVer - WritableDBOV, as in 'C'
State is set by DBObject:Edit() or by modifying any property
After saving origVer stays the same but gets props from curVer, curVer is assigned to new empty WritableDBOV

'D': object is marked for deletion (but not yet deleted from database)
origVer - ReadOnlyDBOV, as in 'R'
curVer - VoidDBOV
This object is not found by subsequent LoadObject (TODO ??? confirm)
After deleting from database, object gets deleted from DBContext.Objects collection

Flow of using:

1) get object by ID - DBContext:LoadObject(ID, forUpdate). If forUpdate == true, object also switches to edit mode
2) to start modification DBObject:Edit() or assign property a new value. If already in edit mode, it is safe no-op
3) to delete, DBObject:Delete()

The following is list of DBObject class family:
VoidDBOBV
BaseDBOV
--ReadOnlyDBOBV
----WritableDBOV

*DBOV
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
local DBProperty = require('DBProperty').DBProperty
local ChangedDBProperty = require('DBProperty').ChangedDBProperty

---@class BaseDBOV
---@method getProp
---@method setProp

--[[
Void DB objects exist as 2 singletons, handling access to inserted.old and deleted.new states
]]
---@class VoidDBOV
local VoidDBOV = class()

---@param state string
function VoidDBOV:_init(tag)
    self.tag = tag
end

---@param propName string
---@param propIndex number @comment optional, if not set, 1 is assumed
function VoidDBOV:getProp(propName, propIndex)
    error(self.tag)
end

function VoidDBOV:setProp(propName, propIndex, propValue)
    error(self.tag)
end

local DeletedVoidDBObject = VoidDBOV('New object is not available in this context')
local CreatedVoidDBObject = VoidDBOV('Old object is not available in this context')

---@class ObjectMetadata
---@field format table <number, table>

---@class ReadOnlyDBOV
---@field ID number @comment > 0 for existing objects, < 0 for newly created objects
---@field ClassDef ClassDef
---@field MetaData ObjectMetadata
---@field DBObject DBObject
---@field props table <string, DBProperty>
---@field ctlo number @comment [.objects].ctlo
---@field vtypes number @comment [.objects].vtypes
local ReadOnlyDBOV = class()

--[[
    DBObject
    ID is required, either ClassDef or DBContext are required, other params are optional.
 ]]
---@class DBObjectCtorParams
---@field ClassDef ClassDef
---@field DBContext DBContext
---@field ID number @comment > 0 - existing object, < 0 - new not yet saved object, 0 - object to be deleted
---@field DBObject DBObject

---@param params DBObjectCtorParams
function ReadOnlyDBOV:_init(params)
    self.ID = assert(params.ID)
    self.DBObject = assert(params.DBObject)

    if self.ID > 0 then
        -- Existing object
        assert(params.DBContext or params.ClassDef, 'Either ClassDef or DBContext are required')
        local DBContext = params.DBContext or params.ClassDef.DBContext
        self:loadObjectRow(DBContext)
    else
        -- New or temporary object
        self.ClassDef = assert(params.ClassDef)
        -- TODO initialize new object
        -- ctlo
    end

    -- Dictionary of DBProperty
    self.props = {}
end

---@param propIDs table <number, number> | number[] | number @comment single property ID or array of property IDs
-- or map of property IDs to fetch count
function ReadOnlyDBOV:loadProps(propIDs)
    if not propIDs then
        -- Nothing to do
        return
    end

    if type(propIDs) ~= 'table' then
        propIDs = { propIDs }
    end

    for propID, fetchCnt in pairs(propIDs) do
        -- TODO
    end
end

-- Loads row from .objects table. Updates ClassDef if previous ClassDef is null or does not match actual definition
---@param propIDs number | number[] | table<number, number> @comment optional
function ReadOnlyDBOV:loadObjectRow(propIDs)
    -- Load from .objects
    local obj = self.DBObject.ClassDef.DBContext:loadOneRow([[select * from [.objects] where ObjectID=:ObjectID;]], { ObjectID = self.ID })

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
            -- TODO Build ctlv
            local ctlv = 0
            --col:byte() -string.byte('A')

            -- Extract cell MetaData
            local dbProp = self.props[prop.Name.text] or DBProperty(self, prop)
            local colMetaData = self.MetaData and self.MetaData.colMapMetaData and self.MetaData.colMapMetaData[prop.PropertyID]
            local cell = DBValue { Object = self, Property = dbProp, PropIndex = 1, Value = obj[col], ctlv = ctlv, MetaData = colMetaData }
            dbProp.values[1] = cell
        end
    end

    if propIDs then
        self:loadProps(propIDs)
    end
end

---@param propName string
---@param propIndex number @comment optional, if not set, 1 is assumed
function ReadOnlyDBOV:getProp(propName, propIndex)
    local propDef = self.ClassDef:getProperty(propName)
    self:checkPropertyAccess(propDef, self.DBObject.state)
    local result = self.props[propName]
    return result
end

--[[ Ensures that all values with PropIndex == 1 and all vector values for properties in the propList are loaded
This is required for updating object. propList is usually determined by list of properties to be updated or to be returned by query
]]
---@param propIDs table @comment (optional) list of PropertyDef
function ReadOnlyDBOV:loadFromDB(propIDs)
    local sql

    self:loadObjectRow()

    -- TODO Optimize: check if .ref-values need to be loaded whatsoever
    -- tables.difference(ClassDef.Properties, propColMap)

    local params = { ObjectID = self.ObjectID }
    if propIDs ~= nil and type(propIDs) ~= 'table' then
        propIDs = { propIDs }
    end

    if propIDs then
        params.PropIDs = JSON.encode(tablex.map(function(prop)
            return prop.PropertyID
        end, propIDs))

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

-- Ensures that user has required permissions for class level
---@param classDef ClassDef
---@param op string @comment 'C' or 'U' or 'D'
function ReadOnlyDBOV:checkClassAccess(classDef, op)
    self.DBContext.ensureCurrentUserAccessForClass(classDef.ClassID, op)
end

-- Ensures that user has required permissions for property level
---@param propDef PropertyDef
---@param op string @comment 'C' or 'U' or 'D'
function ReadOnlyDBOV:checkPropertyAccess(propDef, op)
    if not propDef then
        -- error
    end
    self.DBContext.ensureCurrentUserAccessForProperty(propDef.PropertyID, op)
end

---@param propName string
---@param propIndex number @comment optional, if not set, 1 is assumed
---@param propValue any
function ReadOnlyDBOV:setProp(propName, propIndex, propValue)
    error('Cannot modify read-only object')
end

---@class WritableDBOV : ReadOnlyDBOV
local WritableDBOV = class(ReadOnlyDBOV)

function WritableDBOV:_init(params)
    self:super(params)
end

--[[
Processes deferred unresolved references
]]
function WritableDBOV:resolveReferences()
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

---@param propName string
---@param propIndex number
function WritableDBOV:getProp(propName, propIndex)
    local result = self.props[propName]
    if not result then
        -- TODO Check permissions
        -- Property may not be available for 2 reasons: not yet loaded, and is not defined in class
        local propDef = self.ClassDef:hasProperty(propName)
        if not propDef and self.ClassDef.allowAnyProps then
            propDef = CreateAnyProperty(self.ClassDef.DBContext, self.ClassDef, propName)
        end
        assert(propDef, string.format('Property %s not found', propName))

        result = propDef:CreateDBProperty(self)
        self.props[propName] = result
    end
    return result
end

---@param propName string
---@param propIndex number @comment optional, if not set, 1 is assumed
---@param propValue any
function WritableDBOV:setProp(propName, propIndex, propValue)
    local dbProp = self.props[propName]
    if not dbProp then
        -- TODO Create new property?
        local propDef = self.ClassDef:getProperty(propName)
        dbProp = ChangedDBProperty(self, propDef)
    end
    dbProp:SetValue(propIndex, propValue)
end

function WritableDBOV:setMappedPropertyValue(prop, value)
    -- TODO
end

-- Apply values of mapped columns, if class is set to use column mapping
---@param params table
function WritableDBOV:applyMappedColumnValues(params)
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

-- Inserts new object
function WritableDBOV:saveCreate()
    -- TODO
end

-- Updates existing object
function WritableDBOV:saveUpdate()
    -- TODO
end

function WritableDBOV:getParamsForSaveFullText(params)
    --TODO indexes?
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

function WritableDBOV:getParamsForSaveRangeIndex(params)
    --TODO indexes?
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

---@param data table
function WritableDBOV:saveNestedObjects(data)
    for _, propDef in ipairs(self.ClassDef.DBContext.GetNestedAndMasterProperties(self.ClassDef.ClassID)) do
        local dd = data[propDef.Name.text]
        if dd and type(dd) == 'table' then
            dd['$master'] = self.ID
            -- TODO Init tested object
            --self:saveToDB(propDef.refDef.classRef.text, nil, nil, dd)
        end
    end
end

---@class DBObject
---@field state string @comment 'C', 'R', 'U', 'D'
---@field origVer ReadOnlyDBOV | VoidDBOV
---@field curVer WritableDBOV | VoidDBOV
local DBObject = class()

function DBObject:_init(params, state)
    params.DBObject = self
    self.state = state or Constants.OPERATION.READ
    if state == Constants.OPERATION.CREATE then
        self.origVer = CreatedVoidDBObject
        self.curVer = WritableDBOV(params)
    elseif state == Constants.OPERATION.DELETE then
        self.origVer = ReadOnlyDBOV(params)
        self.curVer = DeletedVoidDBObject(params)
    else
        self.origVer = ReadOnlyDBOV(params)
        self.curVer = WritableDBOV(params)
    end
end

---@param op string @comment 'C', 'U', or 'D
-- TODO op?
function DBObject:saveMultiKeyIndexes(op)
    local function save()
        if op == Constants.OPERATION.DELETE then
            local sql = multiKeyIndexSQL[op] and multiKeyIndexSQL[op][keyCnt]
            self.ClassDef.DBContext:execStatement(sql, { ObjectID = self.old.ID })
        else
            -- TODO
            for idxName, idxDef in pairs(self.ClassDef.D.indexes) do
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

                    if op == Constants.OPERATION.UPDATE and (self.curVer.ID ~= self.origVer.ID
                            or self.curVer.ClassDef.ClassID ~= self.origVer.ClassDef.ClassID) then
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

function DBObject:original()
    if not self._original then
        self._original = setmetatable({}, {
            __index = function(propName)
                return self.origVer:getProp(propName)
            end,

            __newindex = function(propName, propValue)
                error('Cannot modify read-only object')
            end,

            __metatable = nil
        })
    end
    return self._original
end

function DBObject:current()
    if not self._current then
        self._current = setmetatable({}, {
            __index = function(propName)
                return self.curVer:getProp(propName)
            end,

            __newindex = function(propName, propValue)
                return self.curVer:setProp(propName, propValue)
            end,

            __metatable = nil
        })
    end
    return self._current
end

function DBObject:Edit()
    if self.state == Constants.OPERATION.CREATE or self.state == Constants.OPERATION.UPDATE then
        -- Already editing
        return
    end

    if self.state == Constants.OPERATION.DELETE then
        error('Cannot edit deleted object')
    end
    self.state = Constants.OPERATION.UPDATE
    self.curVer = WritableDBOV { ClassDef = self.origVer.ClassDef, ID = self.origVer.ID }
end

function DBObject:Delete()
    if self.state == Constants.OPERATION.DELETE then
        return
    end

    self.state = Constants.OPERATION.DELETE
    self.curVer = DeletedVoidDBObject
end

-- Sets entire object data, including child objects
-- and links (using queries).
-- Object must be in 'C' or 'U' state
---@param data table
function DBObject:SetData(data)
    if not data then
        return
    end
    self:Edit()
    for propName, propValue in pairs(data) do
        self.curVer:setProp(propName, propValue)
    end
end

-- Builds table with all non null property values
-- Includes detail objects. Does not include links
---@param excludeDefault boolean
function DBObject:GetData(excludeDefault)
    local result = {}
    local curVer = self.curVer
    for propName, propDef in pairs(curVer.ClassDef.Properties) do
        local pp = curVer:getProp(propName)
        if pp then
            local pv = pp:GetValue()
            if pv then
                result[propName] = tablex.deepcopy(pv.Value())
            end
        end
    end

    for propName, propList in pairs(curVer.ClassDef.MixinProperties) do
        if #propList == 1 and not curVer.ClassDef.Properties[propName] then
            -- Process properties in mixin classes only if there is no conflict
        else
            -- Other mixin properties are processed as 'nested' objects
        end
    end

    return result
end

---@param classDef ClassDef
---@param data table
function DBObject:processReferenceProperties()
    -- TODO

    --for name, value in pairs(data) do
    --    local prop = self.ClassDef:hasProperty(name)
    --    -- if reference property, proceed recursively
    --    if prop:isReference() then
    --        if prop.rules.type == 'nested' or prop.rules.type == 'master' then
    --            -- Sub-data is data
    --        else
    --            -- Sub-data is query to return ID(s) to update or delete references
    --        end
    --    else
    --        -- assign scalar value or array of scalar values
    --    end
    --end
end

function DBObject:saveToDB()
    local op = self.state

    -- before trigger
    self:fireBeforeTrigger()

    if op == Constants.OPERATION.CREATE then
        self:setDefaultData()
        self.curVer:saveCreate()
    elseif op == Constants.OPERATION.UPDATE then
        self.curVer:saveUpdate()
    elseif op == Constants.OPERATION.DELETE then

    else
        -- no-op
        return
    end

    if op ~= Constants.OPERATION.CREATE and op ~= Constants.OPERATION.UPDATE then
        error('Invalid object state')
    end

    if op == Constants.OPERATION.CREATE then
        self:setDefaultData()
    end

    self:ValidateData()

    self:processReferenceProperties()

    -- set ctlo TODO move to EditDBObject
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
                     MetaData = JSON.encode(self.MetaData) }

    -- Set column mapped values (A - P)
    self.curVer:applyMappedColumnValues(params)

    if op == Constants.OPERATION.CREATE then
        -- New object
        self.ClassDef.DBContext:execStatement([[insert into [.objects] (ClassID, ctlo, vtypes,
        A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, MetaData) values (
        :ClassID, :ctlo, :vtypes, :A, :B, :C, :D, :E, :F, :G, :H, :I, :J, :J, :K, :L, :M, :N, :O, :P);]],
                                              params)
        self.ID = self.ClassDef.DBContext.db:last_insert_rowid()

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
    elseif op == Constants.OPERATION.UPDATE then
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

---@param data table
function DBObject:setDefaultData()
    if self.state == Constants.OPERATION.CREATE then
        for propName, propDef in pairs(self.curVer.ClassDef.Properties) do
            local dd = propDef.D.defaultValue
            if dd ~= nil then
                local pp = self:getProp(propName, op)
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

function DBObject:ValidateData()
    local data = self:GetData()
    local op = self.state
    if op == Constants.OPERATION.CREATE or op == Constants.OPERATION.UPDATE then
        local objSchema = self.curVer.ClassDef:getObjectSchema(op)
        if objSchema then
            local err = schema.CheckSchema(data, objSchema)
            if err then
                -- TODO 'Invalid input data:'
                error(err)
            end
        end
    end
end

function DBObject:fireAfterTrigger()
    -- TODO call custom _after_ trigger (defined in Lua), first for mixin classes (if applicable), then for *this* class

end

function DBObject:Boxed()
    --TODO
end

return DBObject
