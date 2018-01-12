---
--- Created by slanska.
--- DateTime: 2017-12-19 7:12 AM
---

--[[
Internally used facade to [.object] row.
Provides access to property values, saving in database etc.
This is low level data operations, so user permissions are not checked
Holds collection of DBCells (.ref-values)

DBObject
    - Boxed - BoxedDBObject to be accessed in custom scripts
        - props - collection of DBProperty by property name
            - Boxed - BoxedDBProperty
            - values - array of DBCell
                - BoxedDBValue - protected value to be accessed in custom scripts

Main features:
SetData
GetData
new and existing object ID
data validation
access rules
loading data from db
saving data to db
boxed data (user access)
access by property name and index
]]

local class = require 'pl.class'
local bits = type(jit) == 'table' and require('bit') or require('bit32')
local DBCell = require 'DBCell'
local tablex = require 'pl.tablex'
local JSON = require 'cjson'
local Util64 = require 'Util'
local Constants = require 'Constants'
local schema = require 'schema'

--[[]]
---@class DBObject
local DBObject = class()

--- --@class DBProperty
--local DBProperty = class()

-- DBObject constructor.
---@param objectId number @comment (optional) Int64
---@param classDef IClassDef @comment (optional) must be passed if objectId is nil
function DBObject:_init(objectId, classDef)
    if not objectId then
        ---@type ClassDef
        self.ClassDef = assert(classDef, 'ClassDef is required for new objects')
        self.NewID = self.ClassDef.DBContext:GetNewObjectID()
    else
        ---@type number
        self.ID = objectId
        self:loadFromDB()
    end

    -- [.ref-values] & mapped columns collection: Each property is stored by property name as DBProperty
    -- Each ref-value entry is stored in list
    -- as Value, ctlv, OriginalValue

    ---@type table @comment [propName:string]: DBProperty
    self.props = {}
end

-- Loads row from .objects table. Updates ClassDef if needed
function DBObject:loadObjectRow()
    -- Load from .objects
    local obj = self.ClassDef.DBContext:loadOneRow([[select * from [.objects] where ObjectID=:ObjectID;]], { ObjectID = self.ID })
    if obj.MetaData then
        -- object MetaData may include: accessRules, colMapMetaData and other elements
        self.MetaData = JSON.decode(obj.MetaData)
        -- TODO further processing
    else
        self.MetaData = nil
    end

    self.ctlo = obj.ctlo

    -- Theoretically, object ID may not match class def passed in constructor
    if obj.ClassID ~= self.ClassDef.ClassID then
        self.ClassDef = self.ClassDef.DBContext:getClassDef(obj.ClassDef)
    end

    ---@type table
    self.props = {}

    -- Set values from mapped columns
    if self.ClassDef.ColMapActive then
        for col, prop in pairs(self.ClassDef.propColMap) do
            -- Build ctlv
            local ctlv = 0
            --col:byte() -string.byte('A')

            -- Extract cell MetaData
            local colMetaData = self.MetaData and self.MetaData.colMapMetaData and self.MetaData.colMapMetaData[prop.PropertyID]
            local cell = DBCell { Object = self, Property = prop, PropIndex = 1, Value = obj[col], ctlv = ctlv, MetaData = colMetaData }
            self.props[prop.PropertyID] = self.props[prop.PropertyID] or {}
            self.props[prop.PropertyID][1] = cell
        end
    end
end

---@return BoxedDBObject
function DBObject:Boxed()
    if not self.boxed then
        self.boxed = setmetatable({}, {
            __index = function(propName)
                return self:getDBProperty(propName)
            end,

            __newindex = function(propName, propValue)
                return self:setDBProperty(propName, propValue)
            end,

            __metatable = function()
                return nil
            end,

        })
    end

    return self.boxed
end

function DBObject:BoxedDBProperty(propDef)
    -- todo
    if self.prop then

    end
    local result = setmetatable({}, {

    })

    return result
end

---@param propName string
function DBObject:getDBProperty(propName)

end

---@param propName string
---@param propValue any
function DBObject:setDBProperty(propName, propValue)

end

-- Sets entire object data, including child objects
-- and links (using queries)
---@param data table
function DBObject:SetData(data)
    if not data then
        return
    end

    for propName, propValue in pairs(data) do
        self:setDBProperty(propName, propValue)
    end
end

-- Builds table with all non null property values
-- Includes detail objects. Does not include links
function DBObject:GetData()
    local result = {}
    for propName, propDef in pairs(self.ClassDef.Properties) do

    end

    for propName, propList in pairs(self.ClassDef.MixinProperties) do
        if #propList == 1 and not self.ClassDef.Properties[propName] then
            -- Process properties in mixin classes only if there is no conflict
        else
            -- Other mixin properties are processed as 'nested' objects
        end
    end
end

-- Returns ref-value entry for given property ID and index
function DBObject:getRefValue(propID, propIdx)
    local values = self.props[propID]
    if not values then
        values = {}
        self.props[propID] = values
    end

    local rv = values[propIdx]
    if not rv then
        rv = {}
        values[propIdx] = rv
    end

    return rv
end

function DBObject:setPropertyNull(propIdOrName, propIdx)

end

--- Set property value
function DBObject:setProperty(propIdOrName, propIdx, value)
    local rv = self:getRefValue(propID, propIdx)
    rv.Value = value
    rv.ctlv = bits.bor(rv.ctlv or 0, 1) -- TODO
end

function DBObject:setMappedPropertyValue(prop, value)
    -- TODO
end

--- Get property value by id

-- saveToDB

-- validate

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
        [2] = [[update [.multi_key2] set ClassID = :ClassID, Z1 = :1, Z2 = :2 where ObjectID = :ObjectID]],
        [3] = [[update [.multi_key3] set ClassID = :ClassID, Z1 = :1, Z2 = :2, Z3 = :3 where ObjectID = :ObjectID]],
        [4] = [[update [.multi_key4] set ClassID = :ClassID, Z1 = :1, Z2 = :2, Z3 = :3, Z4 = :4 where ObjectID = :ObjectID]],
    }
}

---@param op string @comment 'C', 'U', or 'D'
function DBObject:saveMultiKeyIndexes(op)
    -- TODO multi key - use pcall to catch error

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

            local sql = multiKeyIndexSQL[op] and multiKeyIndexSQL[op][keyCnt]
            if not sql then
                error('Invalid multi-key index update specification')
            end

            self.ClassDef.DBContext:execStatement(sql, p)
        end
    end
end

function DBObject:saveToDB()
    -- insert or update .objects
    self.newObj = not self.ID

    -- Validate data
    local op = self.newObj and 'C' or 'U'
    local objSchema = self.ClassDef:getObjectSchema(op)
    -- TODO use data payload
    schema.CheckSchema(self, objSchema)

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

    if self.newObj then
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
    else
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
            local cell = DBCell(row)
            self.props[row.PropertyID] = self.props[row.PropertyID] or {}
            self.props[row.PropertyID][row.PropIndex] = cell
        end
    end
end

function DBObject:ValidateData()
    -- todo
end

-------------------------------------------------------------------------------
--- DBProperty
-------------------------------------------------------------------------------
-----@param DBObject DBObject
--function DBProperty:_init(DBObject)
--    self.DBObject = assert(DBObject, 'DBObject is required')
--end
--
--function DBProperty:Boxed()
--
--end
--
--function DBProperty:SetData()
--
--end
--
--function DBProperty:GetData()
--
--end

return DBObject