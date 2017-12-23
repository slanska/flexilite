---
--- Created by slanska.
--- DateTime: 2017-12-19 7:12 AM
---

--[[
Internally used facade to [.object] row.
Provides access to property values, saving in database etc.
]]

local class = require 'pl.class'
local bits = type(jit) == 'table' and require('bit') or require('bit32')







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
        self.id = objectId
        self:loadFromDB()
    end

    self.classDef = classDef

    -- [.ref-values] collection: table of table
    -- Each ref-value entry is stored in list
    -- as Value, ctlv, OriginalValue
    self.RV = {}
end

--- Set property value by name
function DBObject:setPropValueByName(propName, propIdx, value)
    local p = self.classDef:getProperty(propName)
    self:setPropertyByID(p.PropertyID, propIdx, value)
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

function DBObject:deletePropertyByName(propName, propIdx)

end

function DBObject:deletePropertyByID(propID, propIdx)

end

--- Set property value by id
function DBObject:setPropertyByID(propID, propIdx, value)
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
    -- Check permission
end

return DBObject