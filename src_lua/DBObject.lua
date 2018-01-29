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
Instances of DBObjectState are kept by DBContext in Objects collection.

There are few classes implemented:

DBObjectState - central object, which support editing and property access.
Has current() and original() methods to access boxed version of current and original versions of data, respectively.
Their internal counterparts are curVer and origVer, which are instances of BaseDBObject and its descendants
Has state field - one of the following value - 'C', 'R', 'U', 'D'


'R': object loaded from database and not yet modified.
curVer is set to ProxyDBObject which redirects all calls to original()
origVer is set to ReadOnlyDBObject. Write operations raise error
Created by DBContext:LoadObject(ID, forUpdate = false). Also, this is state after saving changes to database

'C': object is newly created and not saved yet.
origVer - VoidDBObject - any property access will raise error
curVer - EditDBObject - object allows read and write
Create by DBContext:CreateNew(classDef)
After saving origVer is set to ReadOnlyDBObject with props from curVer, curVer is assigned to ProxyDBObject

'U': object is in edit state and not saved yet
origVer - ReadOnlyDBObject, as in 'R'
curVer - EditDBObject, as in 'C'
State is set by DBObjectState:Edit()
After saving origVer stays the same but gets props from curVer, curVer is assigned to ProxyDBObject

'D': object is marked for deletion (but not yet deleted from database)
origVer - ReadOnlyDBObject, as in 'R'
curVer - VoidDBObject
This object is not found by subsequent LoadObject (TODO ??? confirm)
After deleting from database, object gets deleted from DBContext.Objects collection

Flow of using:

1) get object by ID - DBContext:LoadObject(ID, forUpdate). If forUpdate == true, object also switches to edit mode
2) to start modification DBObjectState:Edit(). If already in edit mode, it is safe no-op
3) to delete, DBObjectState:Delete()

The following is list of DBObject class family:
VoidDBObject
-- ProxyDBObject
---- ReadOnlyDBObject
---- EditDBObject

DBObject
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

--[[
Void DB objects exist as 2 singletons, handling access to inserted.old and deleted.new states
]]
---@class VoidDBObject
local VoidDBObject = class()

---@param state string
function VoidDBObject:_init(tag)
    self.tag = tag
end

---@param propName string
---@return DBProperty
function VoidDBObject:getDBProperty(propName)
    local tag = self.tag == Constants.OPERATION.DELETE and 'New' or 'Old'
    error(string.format('%s object is not available in this context', tag))
end

function VoidDBObject:setDBProperty(propName, propValue)
    local p = self:getDBProperty(propName)
    return p:SetValue(1, propValue)
end

local DeletedVoidDBObject = VoidDBObject('D')
local CreatedVoidDBObject = VoidDBObject('C')

---@class ObjectMetadata
---@field format table <number, table>

---@class ProxyDBObject : VoidDBObject
---@field ID number @comment > 0 for existing objects, < 0 for newly created objects
---@field ClassDef ClassDef
---@field MetaData ObjectMetadata
---@field origVer VoidDBObject
---@field props table <string, DBProperty>
---@field ctlo number @comment [.objects].ctlo
---@field vtypes number @comment [.objects].vtypes
local ProxyDBObject = class(VoidDBObject)

---@class ReadOnlyDBObject : ProxyDBObject
local ReadOnlyDBObject = class(ProxyDBObject)

--[[
    ID is required, either ClassDef or DBContext are required, other params are optional.
    DBObject does not manage DBContext.Objects or DirtyObjects. It behaves as standalone entity.
 ]]
---@class DBObjectCtorParams
---@field ClassDef ClassDef
---@field DBContext DBContext
---@field ID number @comment > 0 - existing object, < 0 - new not yet saved object, 0 - object to be deleted
---@field PropIDs table @comment array of integers
---@field origVer ReadOnlyDBObject

---@param params DBObjectCtorParams
function ProxyDBObject:_init(params)
    self:super()
    self.ID = assert(params.ID)
    self.origVer = assert(params.origVer)

    if self.ID > 0 then
        -- Existing object
        assert(params.DBContext or params.ClassDef, 'Either ClassDef or DBContext are required')
        local DBContext = params.DBContext or params.ClassDef.DBContext
        self:loadObjectRow(DBContext)
        if params.PropIDs then
            self:loadFromDB(params.PropIDs)
        end
    else
        -- New or temporary object
        self.ClassDef = assert(params.ClassDef)
        -- TODO initialize new object
        -- ctlo
    end

    self.props = {}
end

-- Loads row from .objects table. Updates ClassDef if previous ClassDef is null or does not match actual definition
---@param DBContext DBContext
function ReadOnlyDBObject:loadObjectRow(DBContext)
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

---@param propName string
function ProxyDBObject:getDBProperty(propName)
    -- TODO Check permissions

    local result = self.origVer:getDBProperty(propName)
    return result
end

--[[ Ensures that all values with PropIndex == 1 and all vector values for properties in the propList are loaded
This is required for updating object. propList is usually determined by list of properties to be updated or to be returned by query
]]
---@param propList table @comment (optional) list of PropertyDef
function ReadOnlyDBObject:loadFromDB(propList)
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

function ReadOnlyDBObject:LoadAllValues()
    -- TODO
end

-- Ensures that user has required permissions for class level
---@param classDef ClassDef
---@param op string @comment 'C' or 'U' or 'D'
function ProxyDBObject:checkClassAccess(classDef, op)
    self.DBContext.ensureCurrentUserAccessForClass(classDef.ClassID, op)
end

-- Ensures that user has required permissions for property level
---@param propDef PropertyDef
---@param op string @comment 'C' or 'U' or 'D'
function ProxyDBObject:checkPermissionAccess(propDef, op)
    self.DBContext.ensureCurrentUserAccessForProperty(propDef.PropertyID, op)
end

--[[
Processes deferred unresolved references
]]
function EditDBObject:resolveReferences()
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

---@param params DBObjectCtorParams
function ReadOnlyDBObject:_init(params)
    self:super(params)
end

function ReadOnlyDBObject:setDBProperty(propName, propValue)
    error('Cannot modify read-only object')
end

---@class EditDBObject : ProxyDBObject
local EditDBObject = class(ProxyDBObject)

function EditDBObject:_init(params)
    self:super(params)
end

---@param propName string
function EditDBObject:getDBProperty(propName)
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

function EditDBObject:setMappedPropertyValue(prop, value)
    -- TODO
end

-- Apply values of mapped columns, if class is set to use column mapping
---@param params table
function EditDBObject:applyMappedColumns(params)
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

function EditDBObject:getParamsForSaveFullText(params)
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

function EditDBObject:getParamsForSaveRangeIndex(params)
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

---@param op string @comment 'C', 'U', or 'D
-- TODO op?
function DBObjectState:saveMultiKeyIndexes(op)
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

---@param data table
function EditDBObject:saveNestedObjects(data)
    for _, propDef in ipairs(self.ClassDef.DBContext.GetNestedAndMasterProperties(self.ClassDef.ClassID)) do
        local dd = data[propDef.Name.text]
        if dd and type(dd) == 'table' then
            dd['$master'] = self.ID
            -- TODO Init tested object
            --self:saveToDB(propDef.refDef.classRef.text, nil, nil, dd)
        end
    end
end

---@class DBObjectState
---@field state string @comment 'C', 'R', 'U', 'D'
---@field origVer BaseDBObject
---@field curVer BaseDBObject
local DBObjectState = class()

function DBObjectState:_init(params, state)
    self.state = state or Constants.OPERATION.READ
    if state == Constants.OPERATION.CREATE then
        self.origVer = CreatedVoidDBObject
        self.curVer = EditDBObject(params)
    elseif state == Constants.OPERATION.UPDATE then
        self.origVer = ReadOnlyDBObject(params)
        self.curVer = EditDBObject(params)
    else
        self.origVer = ReadOnlyDBObject(params)
        self.curVer = ProxyDBObject(params)
    end
end

function DBObjectState:original()
    if not self._original then
        self._original = setmetatable({}, {
            __index = function(propName)
                return self.origVer:getDBProperty(propName)
            end,

            __newindex = function(propName, propValue)
                error('Cannot modify read-only object')
            end,

            __metatable = nil
        })
    end
    return self._original
end

function DBObjectState:current()
    if not self._current then
        self._current = setmetatable({}, {
            __index = function(propName)
                return self.curVer:getDBProperty(propName)
            end,

            __newindex = function(propName, propValue)
                return self.curVer:setDBProperty(propName, propValue)
            end,

            __metatable = nil
        })
    end
    return self._current
end

function DBObjectState:Edit()
    if self.state == Constants.OPERATION.CREATE or self.state == Constants.OPERATION.UPDATE then
        -- Already editing
        return
    end

    if self.state == Constants.OPERATION.DELETE then
        error('Cannot edit deleted object')
    end
    self.state = Constants.OPERATION.UPDATE
    self.curVer = EditDBObject { ClassDef = self.origVer.ClassDef, ID = self.origVer.ID }
end

function DBObjectState:Delete()
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
function DBObjectState:SetData(data)
    if not data then
        return
    end
    self:Edit()
    for propName, propValue in pairs(data) do
        self.curVer:setDBProperty(propName, propValue)
    end
end

-- Builds table with all non null property values
-- Includes detail objects. Does not include links
---@param excludeDefault boolean
function DBObjectState:GetData(excludeDefault)
    local result = {}
    local curVer = self.curVer
    for propName, propDef in pairs(curVer.ClassDef.Properties) do
        local pp = curVer:getDBProperty(propName)
        if pp then
            result[propName] = tablex.deepcopy(pp:GetValue().Value)
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
function DBObjectState:processReferenceProperties()
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

function DBObjectState:saveToDB()
    local op = self.state

    if op ~= Constants.OPERATION.CREATE and op ~= Constants.OPERATION.UPDATE then
        error('Invalid object state')
    end

    -- before trigger
    self:fireBeforeTrigger()

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
                     MetaData = JSON.encode( self.MetaData ) }

    -- Set column mapped values (A - P)
    self.curVer:applyMappedColumns(params)

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
function DBObjectState:setDefaultData()
    if self.state == Constants.OPERATION.CREATE then
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

function DBObjectState:fireBeforeTrigger()
    -- TODO call custom _before_ trigger (defined in Lua), first for mixin classes (if applicable)

end

function DBObjectState:ValidateData()
    local data = self:GetData()
    local op = self.state
    if op == Constants.OPERATION.CREATE or op == Constants.OPERATION.UPDATE then
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

function DBObjectState:fireAfterTrigger()
    -- TODO call custom _after_ trigger (defined in Lua), first for mixin classes (if applicable), then for *this* class

end

return DBObjectState
