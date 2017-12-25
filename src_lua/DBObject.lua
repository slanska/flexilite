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
local tablex = require 'tablex'
local JSON = require 'cjson'
local Util64 = require 'Util'

--[[]]
---@class DBObject
local DBObject = class()

-- Returns tuple of bit masks and values for property's column code (A - P).
-- Tuple: vtypes mask, vtypes value, ctlo mask, ctlo value
---@param propDef PropertyDef
local function getColMapMasks(propDef)
    local idx = string.lower(propDef.ColMap):byte() - string.byte('a')
    local vtmask = Util64.BNot64(Util64.BLShift64(7, idx * 3))
    local vtype = propDef:GetVType()
    return vtmask
end

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

    self.ClassDef = classDef

    -- [.ref-values] collection: Each property is stored by property ID as array of DBCell-s
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

function DBObject:saveToDB()

    -- Validate data

    local params = { ClassID = self.ClassDef.ClassID }

    self:applyMappedColumns(params)

    -- set ctlo

    -- insert or update .objects
    if not self.ID then
        -- New object
        self.ClassDef.DBObject:execStatement([[insert into [.objects] (ClassID, ctlo, vtypes,
        A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, MetaData) values (
        );]],
        params)
        self.ID = self.ClassDef.DBContext.db:last_insert_rowid()
    else
        -- Existing object
        params.ID = self.ID
        self.ClassDef.DBContext:execStatement([[update [.objects] set ClassID=:ClassID, ctlv=:ctlv,
         vtypes=:vtypes, A=:A, B=:B, C=:C, D=:D, E=:E, F=:F, G=:G, H=:H, J=:J, K=:K, L=:L,
         M=:M, N=:N, O=:O, P=:P, MetaData=:MetaData where ObjectID = :ID]], params)


    end

    -- Save .change_log

    -- Save .ref-values, except references (those will be deferred until all objects in the current batch are saved)
    for i, cell in ipairs(self.RV) do
        if not cell:IsLink() then
            cell:saveToDB()
        else
            -- TODO store references in deferred list
        end
    end

    -- save data, with multi-key, FTS and RTREE update, if applicable

    -- multi key - use pcall to catch error

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