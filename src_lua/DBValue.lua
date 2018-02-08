---
--- Created by slanska.
--- DateTime: 2017-12-20 7:19 PM
---

--[[
Single value holder. Maps to row in [.ref-values] table (or A-P columns in .objects table).

DBCell has no knowledge on column mapping and operates solely as all data is stored in .ref-values only.
This is DBObject responsibility to handle column mapping

Access to object property value to be used in user's custom
functions and triggers.
Provides Boxed() value which implements all table metamethods to mimic functionality
of real property,
so that Order.ShipDate or Order.OrderLines[1] will look as real object
properties.

Always operates as it would be .ref-value item. DBObject internally handles mapping to A..P columns
in .objects table

Uses AccessControl to check access rules

Has following fields:
Value
MetaData
ctlv

For the sake of memory saving and easier data consistency property ID/class, object and property index
are not fields of DBValue. Instead, DBProperty and propIndex are passed to all DBValue's functions as
first 2 parameters. Thus DBObject is accessed from DBProperty.DBObject, PropertyDef from DBProperty.PropDef
]]

local class = require 'pl.class'
local JSON = require 'cjson'

---@class DBValueCtorParams
---@field Value any
---@field ctlv number
---@field MetaData table | string

---@class DBValue
---@field Value any
---@field ctlv number
---@field MetaData table|nil
local DBValue = class()

-- constructor
---@param row DBValueCtorParams
function DBValue:_init(row)
    self.Value = row.Value
    self.ctlv = row.ctlv
    if type(row.MetaData) == 'string' then
        self.MetaData = JSON.decode(row.MetaData)
    else
        self.MetaData = row.MetaData
    end
end

function DBValue:Boxed()
    if not self.boxed then
        self.boxed = setmetatable({}, {
            __metatable = nil,
        -- add, sub...
        })
    end

    return self.boxed
end

---@param DBProperty BaseDBProperty
---@param propIndex number
function DBValue:beforeSaveToDB(DBProperty, propIndex)

    -- Check if there is column mapping
    if DBProperty.PropDef.ColMap then
        DBProperty.DBObject:setMappedPropertyValue(DBProperty.PropDef, self.Value)
    end
end

---@param DBProperty BaseDBProperty
---@param propIndex number
function DBValue:afterSaveToDB(DBProperty, propIndex)

end

---@param DBProperty BaseDBProperty
---@param propIndex number
function DBValue:saveToDB(DBProperty, propIndex)
    if DBProperty.PropDef.ColMap then
        -- Already processed
        return
    end

    local sql
    if DBProperty.DBObject:IsNew() then
        sql = [[insert into [.ref-values] (ObjectID, PropertyID, PropIndex, Value, ctlv, MetaData)
            values (:ObjectID, :PropertyID, :PropIndex, :Value, :ctlv); ]]
    else
        if self.Value == nil then
            sql = [[delete from [.ref-values] where ObjectID = :ObjectID and PropertyID = :PropertyID
                and PropIndex = :PropIndex;]]
        else
            sql = [[insert or replace into [.ref-values] (ObjectID, PropertyID, PropIndex, Value, ctlv, MetaData)
            values (:ObjectID, :PropertyID, :PropIndex, :Value, :ctlv);]]
        end

    end
    local p = { ObjectID = DBProperty.DBObject.ID, PropertyID = DBProperty.PropDef.ID,
                ctlv = self.ctlv, Value = self.Value, PropIndex = propIndex, MetaData = self.MetaData }
    self.Object.ClassDef.DBContext:execStatement(sql, p)
end

function DBValue:isLink()
    -- TODO
end

---@param DBContext DBContext
function DBValue:GetLinkedObject(DBProperty, propIndex)
    local result = DBProperty.ClassDef.DBContext:LoadObject(self.Value)
    return result
end

function DBValue:__tostring()

end

function DBValue:__len()

end

function DBValue:__unm()

end

function DBValue:__add()

end

function DBValue:__sub()

end

function DBValue:__mul()

end

function DBValue:__div()

end

function DBValue:__mod()

end

function DBValue:__pow()

end

function DBValue:__concat()

end

function DBValue:__eq()

end

function DBValue:__lt()

end

function DBValue:__le()
end

return DBValue