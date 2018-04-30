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
ReadOnlyDBOBV
--WritableDBOV

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
local bit52 = require('Util').bit52
local Constants = require 'Constants'
local schema = require 'schema'
local CreateAnyProperty = require('flexi_CreateProperty').CreateAnyProperty
local DBProperty = require('DBProperty').DBProperty
local ChangedDBProperty = require('DBProperty').ChangedDBProperty
local NullDBValue = require('DBProperty').NullDBValue
local DictCI = require('Util').DictCI

-------------------------------------------------------------------------------
--[[
Void DB objects exist as 2 singletons, handling access to inserted.old
and deleted.new states
]]
-------------------------------------------------------------------------------
---@class VoidDBOV
local VoidDBOV = class()

---@param state string
function VoidDBOV:_init(tag)
    self.tag = tag
end

---@param propName string
---@param propIndex number @comment optional, if not set, 1 is assumed
function VoidDBOV:getPropValue(propName, propIndex)
    error(self.tag)
end

function VoidDBOV:setPropValue(propName, propIndex, propValue)
    error(self.tag)
end

local DeletedVoidDBObject = VoidDBOV('New object is not available in this context')
local CreatedVoidDBObject = VoidDBOV('Old object is not available in this context')

-------------------------------------------------------------------------------
-- ReadOnlyDBOV
----------------------------------------------------------------------------------

---@class ObjectMetadata
---@field format table <number, table>

---@class ReadOnlyDBOV
---@field ID number @comment > 0 for existing objects, < 0 for newly created objects
---@field ClassDef ClassDef
---@field MetaData ObjectMetadata
---@field DBObject DBObject
---@field props table <string, DBProperty> @comment DictCI
---@field ctlo number @comment [.objects].ctlo
---@field vtypes number @comment [.objects].vtypes
local ReadOnlyDBOV = class()

---@param DBObject DBObject
---@param ID number
function ReadOnlyDBOV:_init(DBObject, ID)
    self.ID = assert(ID)
    self.DBObject = assert(DBObject)
    self.props = DictCI()
end

-- Create pure readonly dbobject version and load .objects data
---@param DBObject DBObject
---@param ID number
---@param objRow table | nil @comment row of [.objects]
---@return ReadOnlyDBOV
function ReadOnlyDBOV.Create(DBObject, ID, objRow)
    local result = ReadOnlyDBOV(DBObject, ID)
    result:loadObjectRow(objRow)
    return result
end

--[[ Loads specific property values. propIDs can be:
1) single property ID
2) dictionary of property IDs
3) dictionary of property IDs as keys and fetchCount as values
]]
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
        local propDef = assert(self.ClassDef.DBContext.ClassProps[propID])
        -- getProp will force loading data for up to specific property index
        self:getPropValue(propDef.Name.text, fetchCnt)
    end
end

---@param obj table @comment [.objects] row
function ReadOnlyDBOV:initFromObjectRow(obj)
    -- Theoretically, object ID may not match class def passed in constructor
    if not self.ClassDef or obj.ClassID ~= self.ClassDef.ClassID then
        self.ClassDef = self.DBObject.DBContext:getClassDef(obj.ClassID)
    end

    if obj.MetaData then
        -- object MetaData may include: accessRules, colMapMetaData and other elements
        self.MetaData = JSON.decode(obj.MetaData)
        -- TODO further processing
    else
        self.MetaData = nil
    end

    self.ctlo = obj.ctlo
    self.vtypes = obj.vtypes

    -- Set values from mapped columns
    if self.ClassDef.ColMapActive then
        for col, prop in pairs(self.ClassDef.propColMap) do
            -- Build ctlv from ctlo and vtypes
            local ctlv = 0
            local colIdx = col:byte() - string.byte('A')
            if bits.band(self.ctlo, bits.lshift(Constants.CTLO_FLAGS.UNIQUE_SHIFT + colIdx)) ~= 0 then
                ctlv = bits.bor(ctlv, Constants.CTLV_FLAGS.UNIQUE)
            end

            if bits.band(self.ctlo, bits.lshift(Constants.CTLO_FLAGS.INDEX_SHIFT + colIdx)) ~= 0 then
                ctlv = bits.bor(ctlv, Constants.CTLV_FLAGS.INDEX)
            end

            local vtype = bit52.lshift(self.vtypes, 3 * (colIdx + 1))
            bit52.set(ctlv, Constants.CTLV_FLAGS.VTYPE_MASK, vtype)

            -- Extract cell MetaData
            local dbProp = self.props[prop.Name.text] or DBProperty(self, prop)
            local colMetaData = self.MetaData and self.MetaData.colMapMetaData and self.MetaData.colMapMetaData[prop.ID]
            local cell = DBValue { Object = self, Property = dbProp, PropIndex = 1, Value = obj[col], ctlv = ctlv, MetaData = colMetaData }
            dbProp.values[1] = cell
        end
    end
end

-- Loads row from .objects table. Updates ClassDef if previous ClassDef is null
-- or does not match actual definition
---@param obj table @comment row of [.objects]
function ReadOnlyDBOV:loadObjectRow(obj)
    -- Load from .objects
    if not obj then
        obj = self.DBObject.DBContext:loadOneRow([[select * from [.objects] where ObjectID=:ObjectID;]], { ObjectID = self.ID })
    end
    self:initFromObjectRow(obj)
end

---@param propName string
---@return DBProperty
function ReadOnlyDBOV:getProp(propName)
    local propDef = self.ClassDef:hasProperty(propName)
    if not propDef then
        return nil
    end

    -- TODO Optimize
    self:checkPropertyAccess(propDef, self.DBObject.state)
    local result = self.props[propName]
    if not result then
        result = DBProperty(self, propDef)
        self.props[propName] = result
    end

    return result
end

---@param propName string
---@param propIndex number @comment optional, if not set, 1 is assumed
---@return DBValue | nil
function ReadOnlyDBOV:getPropValue(propName, propIndex)
    ---@type DBProperty
    local result = self:getProp(propName)
    if result then
        return result:GetValue(propIndex)
    end

    return NullDBValue
end

-- Ensures that user has required permissions for class level
---@param op string @comment 'C' or 'U' or 'D'
function ReadOnlyDBOV:checkClassAccess(op)
    self.ClassDef.DBContext.ensureCurrentUserAccessForClass(self.ClassDef.ClassID, op)
end

-- Ensures that user has required permissions for property level
---@param propDef PropertyDef
---@param op string @comment 'C' or 'U' or 'D'
function ReadOnlyDBOV:checkPropertyAccess(propDef, op)
    self.ClassDef.DBContext.ensureCurrentUserAccessForProperty(propDef.ID, op)
end

---@param propName string
---@param propIndex number @comment optional, if not set, 1 is assumed
---@param propValue any
function ReadOnlyDBOV:setPropValue(propName, propIndex, propValue)
    error('Cannot modify read-only object')
end

-- Returns full object payload, based on propIDs
---@param propIDs nil | number | table<number, number>
---@return table
function ReadOnlyDBOV:getCompleteDataPayload(propIDs)
    local result = {}
    self:loadProps(propIDs)
    for propName, dbp in pairs(self.props) do
        result[propName] = dbp:GetValues()
    end

    return result
end

-------------------------------------------------------------------------------
-- WritableDBOV
-------------------------------------------------------------------------------

---@class WritableDBOV : ReadOnlyDBOV
local WritableDBOV = class(ReadOnlyDBOV)

---@param DBObject DBObject
---@param ClassDef ClassDef
---@param ID number
function WritableDBOV:_init(DBObject, ClassDef, ID)
    self:super(DBObject, ID)
    self.ClassDef = assert(ClassDef)
end

--[[
Processes deferred unresolved references
]]
function WritableDBOV:resolveReferences()
    -- TODO Needed?
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

-- Ensures that PropertyDef exists if ClassDef allows ad-hoc properties
-- Throws error if property does not exist and cannot be created
---@param propName string
---@return PropertyDef
function WritableDBOV:ensurePropertyDef(propName)
    local result = self.ClassDef:hasProperty(propName)
    if not result then
        if self.ClassDef.D.allowAnyProps then
            result = CreateAnyProperty(self.ClassDef.DBContext, self.ClassDef, propName)
        end
    end

    if not result then
        error(string.format('Property %s.%s not found', self.ClassDef.Name.text, propName))
    end

    return result
end

---@param propName string
---@param op string @comment 'C', 'R', 'U', 'D'
---@param returnNil boolean @comment if true, will return nil for not found property. Otherwise, will raise error
---@return DBProperty | nil
function WritableDBOV:getProp(propName, op, returnNil)
    local result = self.props[propName]

    if not result then
        if op == Constants.OPERATION.READ then
            if self.DBObject.state ~= Constants.OPERATION.CREATE then
                result = self.DBObject.origVer:getProp(propName)
            end
        else
            if op == Constants.OPERATION.CREATE or op == Constants.OPERATION.UPDATE then
                local propDef = self:ensurePropertyDef(propName)
                result = ChangedDBProperty(self, propDef)
                self.props[propName] = result
            end
        end
    end

    if not result and not returnNil then
        error(string.format('Property %s.%s not found', self.ClassDef.Name.text, propName))
    end

    return result
end

---@param propName string
---@param propIndex number
---@param returnNil boolean
---@return DBValue | nil
function WritableDBOV:getPropValue(propName, propIndex, returnNil)
    local prop = self:getProp(propName, Constants.OPERATION.READ, returnNil)
    if prop then
        return prop:GetValue(propIndex)
    end

    return NullDBValue
end

-- Returns all values for the given property
-- If maxLength == 1, return scalar value, if maxLength > 1, always returns array of values
---@param propName string
---@return any
function WritableDBOV:getPropValues(propName)
    local prop = self:getProp(propName, self.DBObject.state, true)
    if prop then
        local result = prop:GetValues()
        return result
    end

    return nil
end

---@param propName string
---@param propIndex number @comment optional, if not set, 1 is assumed
---@param propValue any
---@return nil
function WritableDBOV:setPropValue(propName, propIndex, propValue)
    local prop = self:getProp(propName, self.DBObject.state, false)
    prop:SetValue(propIndex, propValue)
end

-- Apply values of mapped columns to params, for insert or update operation
---@param params table
function WritableDBOV:applyMappedColumnValues(params)
    if self.ClassDef.ColMapActive then
        for col, prop in pairs(self.ClassDef.propColMap) do
            local vv = self:getPropValue(prop.ID, 1, true)
            if vv then
                local colIdx = col:byte() - string.byte('A')
                -- update vtypes
                self.vtypes = bit52.set(self.vtypes, bit52.lshift(Constants.CTLV_FLAGS.VTYPE_MASK, colIdx * 3), vv.ctlv)

                -- update ctlo
                self.ctlo = bit52.set(self.ctlo, bit52.lshift(1, Constants.CTLO_FLAGS.INDEX_SHIFT + colIdx), prop.D.indexing == 'index' and 1 or 0)
                self.ctlo = bit52.set(self.ctlo, bit52.lshift(1, Constants.CTLO_FLAGS.UNIQUE_SHIFT + colIdx), prop.D.indexing == 'unique' and 1 or 0)
                params[col] = vv.Value
            else
                params[col] = nil
            end
        end
    end
end

-- Inserts new object
function WritableDBOV:saveCreate()
    -- set ctlo & vtypes
    self:setObjectMetaData()
    local params = { ClassID = self.ClassDef.ClassID, ctlo = self.ctlo, vtypes = self.ClassDef.vtypes,
                     MetaData = self.MetaData and JSON.encode(self.MetaData) or nil }

    -- Set column mapped values (A - P)
    self:applyMappedColumnValues(params)

    --[[
    insert into .objects
    insert into .ref-values
    insert into .full_text_data
    insert into .range_data_
    insert into .multi_keyX

    insert/defer links
    ]]

    -- New object
    self.ClassDef.DBContext:execStatement([[insert into [.objects] (ClassID, ctlo, vtypes,
        A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, MetaData) values (
        :ClassID, :ctlo, :vtypes, :A, :B, :C, :D, :E, :F, :G, :H, :I, :J, :J, :K, :L, :M, :N, :O, :P);]],
                                          params)
    -- TODO process deferred links
    self.ClassDef.DBContext.Objects[self.ID] = nil
    self.ID = self.ClassDef.DBContext.db:last_insert_rowid()
    self.ClassDef.DBContext.Objects[self.ID] = self.DBObject

    for propName, prop in pairs(self.props) do
        prop:SaveToDB()
    end

    -- Save multi-key index if applicable
    self.DBObject:saveMultiKeyIndexes(Constants.OPERATION.CREATE)

    -- Save full text index, if applicable
    local fts = {}
    if self:getParamsForSaveFullText(fts) then
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

    --TODO
    --self:processReferenceProperties()

    -- TODO Save .change_log

    -- Save nested/child objects
    -- TODO
    --self:saveNestedObjects()
end

-- Updates existing object
function WritableDBOV:saveUpdate()
    self:setObjectMetaData()
    local params = { ClassID = self.ClassDef.ClassID, ctlo = self.ctlo, vtypes = self.ClassDef.vtypes,
                     MetaData = JSON.encode(self.MetaData) }

    self:applyMappedColumnValues(params)

    --[[
    update .objects
    insert/update/delete .ref-values
    insert/update/delete .full_text_data
    insert/update/delete .range_data_
    update .multi_keyX

    insert/update/delete/defer links
    ]]
    -- Existing object
    params.ID = self.ID
    self.ClassDef.DBContext:execStatement([[update [.objects] set ClassID=:ClassID, ctlv=:ctlv,
         vtypes=:vtypes, A=:A, B=:B, C=:C, D=:D, E=:E, F=:F, G=:G, H=:H, J=:J, K=:K, L=:L,
         M=:M, N=:N, O=:O, P=:P, MetaData=:MetaData where ObjectID = :ID]], params)

    for propName, prop in pairs(self.props) do
        prop:SaveToDB()
    end

    -- Save multi-key index if applicable
    self.DBObject:saveMultiKeyIndexes(Constants.OPERATION.UPDATE)

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
end

-- Initializes params for .full_text_data insert/update
function WritableDBOV:getParamsForSaveFullText(params)
    --TODO indexes?
    if not (self.ClassDef.fullTextIndexing and tablex.size(self.ClassDef.fullTextIndexing) > 0) then
        return false
    end

    params.ClassID = self.ClassDef.ClassID
    params.docid = self.ID

    for key, propRef in pairs(self.ClassDef.fullTextIndexing) do
        local vv = self:getProp(propRef.Name.text, 1)
        if vv then
            local v = vv.Value
            -- TODO Check type and value?
            if type(v) == 'string' then
                params[key] = v
            end
        end
    end

    return true
end

-- Initializes params for .range_data_ insert/update
function WritableDBOV:getParamsForSaveRangeIndex(params)
    --TODO indexes?
    if not (self.ClassDef.rangeIndex and tablex.size(self.ClassDef.rangeIndex) > 0) then
        return false
    end

    params.ObjectID = self.ID

    -- TODO check if all values are not null
    for key, propRef in pairs(self.ClassDef.rangeIndex) do
        local vv = self:getProp(propRef.Name.text, 1)
        if vv then
            params[key] = vv.Value
        end
    end

    return true
end

-- SQL for updating multi-key indexes
local multiKeyIndexSQL = {
    -- Create
    C = {
        [2] = [[insert into [.multi_key2] (ObjectID, ClassID, Z1, Z2)
        values (:ObjectID, :ClassID, :1, :2);]],
        [3] = [[insert into [.multi_key3] (ObjectID, ClassID, Z1, Z2, Z3)
        values (:ObjectID, :ClassID, :1, :2, :3);]],
        [4] = [[insert into [.multi_key4] (ObjectID, ClassID, Z1, Z2, Z3, Z4)
        values (:ObjectID, :ClassID, :1, :2, :3, :4);]],
    },
    -- Update
    U = {
        [2] = [[update [.multi_key2] set ClassID = :ClassID, Z1 = :1, Z2 = :2
        where ClassID = :old_ClassID and Z1 = :11 and Z2 = :12;]],
        [3] = [[update [.multi_key3] set ClassID = :ClassID, Z1 = :1, Z2 = :2, Z3 = :3
        where ClassID = :old_ClassID and Z1 = :11 and Z2 = :12 and Z3 = :13;]],
        [4] = [[update [.multi_key4] set ClassID = :ClassID, Z1 = :1, Z2 = :2, Z3 = :3, Z4 = :4
        where ClassID = :old_ClassID and Z1 = :11 and Z2 = :12 and Z3 = :13 and Z4 = :14;]],
    },
    -- Extended version of update when ObjectID and/or ClassID changed
    UX = {
        [2] = [[update [.multi_key2]
        set ClassID = :ClassID, Z1 = :1, Z2 = :2, ObjectID = :ObjectID
        where ClassID = :old_ClassID and Z1 = :11 and Z2 = :12;]],
        [3] = [[update [.multi_key3]
        set ClassID = :ClassID, Z1 = :1, Z2 = :2, Z3 = :3, ObjectID = :ObjectID
        where ClassID = :old_ClassID and Z1 = :11 and Z2 = :12 and Z3 = :13;]],
        [4] = [[update [.multi_key4]
        set ClassID = :ClassID, Z1 = :1, Z2 = :2, Z3 = :3, Z4 = :4, ObjectID = :ObjectID
        where ClassID = :old_ClassID and Z1 = :11 and Z2 = :12 and Z3 = :13 and Z4 = :14;]],
    },
    -- Delete
    D = {
        [2] = [[delete from [.multi_key2]
        where ClassID = :old_ClassID and Z1 = :11 and Z2 = :12;]],
        [3] = [[delete from [.multi_key3]
        where ClassID = :old_ClassID and Z1 = :11 and Z2 = :12 and Z3 = :13;]],
        [4] = [[delete from [.multi_key4]
        where ClassID = :old_ClassID and Z1 = :11 and Z2 = :12 and Z3 = :13 and Z4 = :14;]]
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

function WritableDBOV:setObjectMetaData()
    local ctlo = self.ClassDef.ctlo
    if self.MetaData then
        if self.MetaData.accessRules then
            ctlo = bit52.bor(ctlo, Constants.CTLO_FLAGS.HAS_ACCESS_RULES)
        end

        if self.MetaData.formulas then
            ctlo = bit52.bor(ctlo, Constants.CTLO_FLAGS.HAS_FORMULAS)
        end

        if self.MetaData.colMetaData then
            ctlo = bit52.bor(ctlo, Constants.CTLO_FLAGS.HAS_COL_META_DATA)
        end
    end
    self.ctlo = ctlo
end

-- Returns data of all changed properties
---@return table
function WritableDBOV:getChangedDataPayload()
    local result = {}
    for propName, dbp in pairs(self.props) do
        result[string.lower(propName)] = dbp:GetValues()
    end
    return result
end

-------------------------------------------------------------------------------
--[[
Utility class for boxed access to DBObject and registered user functions.
Used in filtering, user functions and triggers
]]
-------------------------------------------------------------------------------
---@class DBObjectWrap
---@field DBOV ReadOnlyDBOV
---@field boxed table

local DBObjectWrap = class()

---@param DBContext DBContext
---@param objectID number | nil
---@param objRow table | nil @comment row of [.objects]
function DBObjectWrap:_init(DBOV)
    self.DBOV = assert(DBOV)
end

---@param name string
---@return DBProperty | nil
function DBObjectWrap:getDBObjectProp(name)
    if self.DBOV then
        local result = self.DBOV:getProp(name)
        return result
    end
end

---@param name string
function DBObjectWrap:getRegisteredFunc(name)
    -- TODO
    return nil
end

---@param name string
function DBObjectWrap:getBoxedAttr(name)

    -- If DBObject is assigned, check its properties first
    local prop = self:getDBObjectProp(name)
    if prop then
        local result = prop:Boxed()

        --[[
        FIXME
        This is temporary implementation caused by the fact that Lua does not call __eq handler if metatables of operands are not
        the same. To allow == and ~= comparison to work we check if property has maximum occurrence equal to 1 and in that
        case return actual value for item 1.
        This peculiar implementation somewhat contradicts philosophy of Flexilite to allow reasonable flexibility, i.e. treat
        Prop and Prop[1] as the same, regardless if maxOccurrences is 1 or more.
        Due to specific implementation of __eq in Lua, to handle this properly we would need to change original Lua/LuaJIT C code
        (lj_record.c) to handle __eq similarly to __le and __lt metamethods.
        ]]
        if result and (prop.PropDef.D.rules.maxOccurrences or 1) == 1 then
            return result:ValueGetter()
        end

        return result
    end

    -- Check registered user functions
    local func = self:getRegisteredFunc(name)
    if func then
        -- TODO
    end

    return rawget(self, name)
end

function DBObjectWrap:Boxed()
    if not self.boxed then
        self.boxed = setmetatable({}, {
            __index = function(boxed, name)
                return self:getBoxedAttr(name)
            end,
            __newindex = function(boxed, name, value)
                local result = self:getDBObjectProp(name)
                if result then
                else
                    -- TODO Temp
                    rawset(self, name, value)
                end

            end,
            __metatable = nil,
        })
    end
    return self.boxed
end

-------------------------------------------------------------------------------
-- DBObject
-------------------------------------------------------------------------------

---@class DBObject
---@field state string @comment 'C', 'R', 'U', 'D'
---@field origVer ReadOnlyDBOV | VoidDBOV
---@field curVer WritableDBOV | VoidDBOV
---@field DBContext DBContext
local DBObject = class()

---@class DBObjectCtorParams
---@field ID number
---@field ClassDef ClassDef
---@field DBContext DBContext @comment optional if ClassDef is supplied
---@field Data table @comment optional data payload
---@field ObjRow table | nil @comment row of [.objects]

---@param params DBObjectCtorParams
---@param state string @comment optional, 'C', 'R', 'U', 'D'
function DBObject:_init(params, state)
    self.state = state or Constants.OPERATION.READ
    self.DBContext = assert(params.DBContext or params.ClassDef.DBContext)

    if self.state == Constants.OPERATION.CREATE then
        self.origVer = CreatedVoidDBObject
        self.curVer = WritableDBOV(self, assert(params.ClassDef), params.ID)
        if params.Data then
            self:SetData(params.Data)
        end
    else
        self.origVer = ReadOnlyDBOV.Create(self, params.ID, params.ObjRow)

        if self.state == Constants.OPERATION.DELETE then
            self.curVer = DeletedVoidDBObject
        else
            self.curVer = WritableDBOV(self, self.origVer.ClassDef, params.ID)
            if params.Data then
                self:SetData(params.Data)
            end
        end
    end
end

-- Provides read only boxed (protected) access to properties or original object
function DBObject:original()
    if not self._original then
        self._original = setmetatable({}, {
            __index = function(propName)
                return self.origVer:getPropValue(propName)
            end,

            __newindex = function(propName, propValue)
                error('Cannot modify read-only object')
            end,

            __metatable = nil
        })
    end
    return self._original
end

-- Provides read and write boxed (protected) access to properties or current object
function DBObject:current()
    if not self._current then
        self._current = setmetatable({}, {
            __index = function(propName)
                return self.curVer:getPropValue(propName)
            end,

            __newindex = function(propName, propValue)
                return self.curVer:setPropValue(propName, 1, propValue)
            end,

            __metatable = nil
        })
    end
    return self._current
end

-- Starts edit mode. If already in CREATE/UPDATE state, this is no op
function DBObject:Edit()
    if self.state == Constants.OPERATION.CREATE or self.state == Constants.OPERATION.UPDATE then
        -- Already editing
        return
    end

    if self.state == Constants.OPERATION.DELETE then
        error('Cannot edit deleted object')
    end

    self.state = Constants.OPERATION.UPDATE
end

-- Deletes object from database
function DBObject:Delete()
    if self.state == Constants.OPERATION.DELETE then
        return
    end

    self.state = Constants.OPERATION.DELETE
    self.curVer = DeletedVoidDBObject

    assert(self.old)
    local sql = [[delete from [.objects] where ObjectID = :ObjectID;]]
    local args = { ObjectID = self.old.ID }
    self.ClassDef.DBContext:execStatement(sql, args)

    sql = [[delete from [.ref-values] where ObjectID = :ID]]
    self.ClassDef.DBContext:execStatement(sql, args)

    sql = string.format([[delete from [.range_data_%d] were ObjectID = :ObjectID;]], self.ClassDef.ClassID)
    self.ClassDef.DBContext:execStatement(sql, args)

    self:saveMultiKeyIndexes(Constants.OPERATION.DELETE)
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
        self.curVer:setPropValue(propName, 1, propValue)
    end
end

-- Builds table with all non null property values
-- Includes nested objects. Does not include links
---@param excludeDefault boolean @comment if true, default data will not be included into result
---@return table @comment JSON-compatible payload with property names
function DBObject:GetData(excludeDefault)
    if self.state == Constants.OPERATION.DELETE then
        error(string.format('Cannot get data of deleted object %d', self.origVer.ID))
    end

    local result = {}
    local curVer = self.curVer
    for propName, propDef in pairs(curVer.ClassDef.Properties) do
        -- TODO get all indexes 1..N
        local pv = curVer:getPropValues(propName)

        -->>
        print('DBObject:GetData ', propName, type(pv), pv)

        if pv and type(pv) == 'table' then
            require('pl.pretty').dump(pv)
            local vv = pv.Value
            if vv then
                result[propName] = tablex.deepcopy(pv.Value)
            end
        else
            result[propName] = pv
        end
    end

    for propName, propList in pairs(curVer.ClassDef.MixinProperties) do
        if #propList == 1 and not curVer.ClassDef.Properties[propName] then
            -- Process properties in mixin classes only if there is no prop name conflict
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

    -- TODO safe call
    local ok, err = xpcall(function()
        -- before trigger
        self:fireBeforeTrigger()

        if op == Constants.OPERATION.CREATE then
            self:setMissingDefaultData()
            self:ValidateData()
            self.curVer:saveCreate()
        elseif op == Constants.OPERATION.UPDATE then
            self:ValidateData()
            self.curVer:saveUpdate()
        elseif op == Constants.OPERATION.DELETE then
            --self:Delete()
        else
            -- no-op
            return
        end

        -- After trigger
        self:fireAfterTrigger()

    end,
                           function(err)
                               print(string.format('>>> saveToDB error %s:%d', self.curVer.ClassDef.Name.text, self.curVer.ID))
                               return err
                           end)

    if err then
        error(err)
    end
end

-- Sets default data to those properties that have not been assigned
---@param data table
function DBObject:setMissingDefaultData()
    if self.state == Constants.OPERATION.CREATE then
        for propName, propDef in pairs(self.curVer.ClassDef.Properties) do
            local prop = self.curVer.props[propName]
            if prop == nil or prop.values == nil or #prop.values == 0 then
                local dd = propDef.D.defaultValue
                if dd ~= nil then
                    -- TODO assign all property values
                    local pp = self.curVer:setPropValue(propName, 1, tablex.deepcopy(dd))
                    --local vv = pp:GetValue()

                    --                if vv == nil then
                    --                  pp:SetValue(1, tablex.deepcopy(dd))
                    --            end
                end
            end
        end
    end
end

function DBObject:fireBeforeTrigger()
    -- TODO call custom _before_ trigger (defined in Lua), first for mixin classes (if applicable)

end

function DBObject:ValidateData()
    local data = self.curVer:getChangedDataPayload()

    local op = self.state
    if op == Constants.OPERATION.CREATE or op == Constants.OPERATION.UPDATE then
        local objSchema = self.curVer.ClassDef:getObjectSchema(op)
        if objSchema then
            local err = schema.CheckSchema(data, objSchema)
            if err then
                error(err)
            end
        end
    end
end

function DBObject:fireAfterTrigger()
    -- TODO call custom _after_ trigger (defined in Lua), first for mixin classes (if applicable), then for *this* class

end

function DBObject:InitFromObjectRow(obj)
    self.curVer:initFromObjectRow(obj)
end

---@param mode string @comment DBOBJECT_SANDBOX_MODE 'F', 'O', 'C', 'E'
function DBObject:GetSandBoxed(mode)
    mode = mode or Constants.DBOBJECT_SANDBOX_MODE.FILTER
    if mode == Constants.DBOBJECT_SANDBOX_MODE.FILTER
            or mode == Constants.DBOBJECT_SANDBOX_MODE.EXPRESSION then
        return DBObjectWrap(self.origVer):Boxed()
    elseif mode == Constants.DBOBJECT_SANDBOX_MODE.ORIGINAL then
        return self.original()
    elseif mode == Constants.DBOBJECT_SANDBOX_MODE.CURRENT then
        return self.current()
    else
        error(string.format('Unknown sandboxed mode %s', tostring(mode)))
    end
end

---@param op string @comment 'C', 'U', or 'D
function DBObject:saveMultiKeyIndexes(op)

    -- Local function to be called in protected mode to handle unique constraint violation in
    -- a user friendly way
    local function save()
        local dbov = op == Constants.OPERATION.DELETE and self.origVer or self.curVer

        local multiKeyPropIDs = dbov.ClassDef.indexes.multiKeyIndexing
        if not multiKeyPropIDs or #multiKeyPropIDs == 0 then
            return
        end

        local set_old_values = op == Constants.OPERATION.DELETE or op == Constants.OPERATION.UPDATE
        local set_new_values = op == Constants.OPERATION.CREATE or op == Constants.OPERATION.UPDATE

        local params = {}
        for i, propId in ipairs(multiKeyPropIDs) do
            local propDef = self.ClassDef.DBContext.ClassProps[propId]
            assert(propDef.ClassDef.ClassID == self.ClassDef.ClassID) -- TODO Detailed error message

            local propVal = dbov:getPropValue(propDef.Name.text, 1)
            if propVal then
                params[tostring(i)] = propVal.Value
            end

            if set_old_values then
                propVal = self.origVer:getPropValue(propDef.Name.text, 1)
                if propVal then
                    params[tostring(i + 10)] = propVal.Value
                end
            end
        end

        if set_old_values then
            params.old_ClassID = self.origVer.ClassDef.ClassID
            params.old_ObjectID = self.origVer.ID
        end

        if set_new_values then
            params.ObjectID = self.ID
        end

        local sql = multiKeyIndexSQL[op] and multiKeyIndexSQL[op][#multiKeyPropIDs]
        self.ClassDef.DBContext:execStatement(sql, params)
    end

    local ok, errMsg = xpcall(save,
                              function(error)
                                  local errorMsg = tostring(error)

                                  return string.format('Error updating multi-key unique index: %d', errorMsg)
                              end)

    if errMsg then
        error(errMsg)
    end
end

return DBObject
