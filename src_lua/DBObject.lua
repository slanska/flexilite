---
--- Created by slanska.
--- DateTime: 2017-12-19 7:12 AM
---

--[[
Internally used facade to [.object] row.
Provides access to property values, saving in database etc.
This is low level data operations, so user permissions are not checked
Holds collection of DBCells (.ref-values)
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

---@param DBContext DBContext
---@param objectId number @comment (optional) Int64
---@param classDef IClassDef @comment (optional) must be passed if objectId is nil
function DBObject:_init(DBContext, classDef, objectId)
    self.DBContext = DBContext
    if not objectId then
        assert(classDef)
    else
        self.ID = objectId
        self:loadFromDB()
    end

    ---@type ClassDef
    self.ClassDef = classDef

    -- [.ref-values] collection: Each property is stored by property ID as array of DBCells
    -- Each ref-value entry is stored in list
    -- as Value, ctlv, OriginalValue
    self.RV = {}
end

-- Returns ref-value entry for given property ID and index
function DBObject:getRefValue(propID, propIdx)
    local values = self.RV[propID]
    if not values then
        values = {}
        self.RV[propID] = values
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

-- Loads object data including direct properties from .ref-values
-- Nested objects are loaded too, using nestedDepth configuration value
---@param propIdList table @comment (optional) list of selected property IDs to load
function DBObject:loadFromDB(propIdList)
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
    for i, cell in ipairs(self.RV) do
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

    -- Load from .objects
    local obj = self.ClassDef.DBContext:loadOneRow([[select * from [.objects] where ObjectID=:ObjectID;]], { ObjectID = self.ID })
    if obj.MetaData then
        -- object MetaData may include: accessRules, colMapMetaData and other elements
        self.MetaData = JSON.decode(obj.MetaData)
    else
        self.MetaData = nil
    end

    self.ctlo = obj.ctlo


    -- TODO check obj.ClassID

    self.RV = {}

    -- Set values from mapped columns
    if self.ClassDef.ColMapActive then
        for col, prop in pairs(self.ClassDef.propColMap) do
            -- Build ctlv
            local ctlv = 0
            --col:byte() -string.byte('A')

            -- Extract cell MetaData
            local colMetaData = self.MetaData and self.MetaData.colMapMetaData and self.MetaData.colMapMetaData[prop.PropertyID]
            local cell = DBCell { Object = self, Property = prop, PropIndex = 1, Value = obj[col], ctlv = ctlv, MetaData = colMetaData }
            self.RV[prop.PropertyID] = self.RV[prop.PropertyID] or {}
            self.RV[prop.PropertyID][1] = cell
        end
    end

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
        if not self.RV[row.PropertyID][row.PropIndex] then
            row.Object = self
            row.Property = self.ClassDef.DBContext.ClassProps[row.PropertyID]
            local cell = DBCell(row)
            self.RV[row.PropertyID] = self.RV[row.PropertyID] or {}
            self.RV[row.PropertyID][row.PropIndex] = cell
        end
    end
end

return DBObject