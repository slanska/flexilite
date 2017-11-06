---
--- Created by slanska.
--- DateTime: 2017-10-31 3:18 PM
---

--[[
Property definition
Keeps name, id, reference to class definition
Provides API for property definition validation, type change etc
]]

require 'math'
require 'bit'

-- Candidates for common.lua
local MAX_NUMBER = 1.7976931348623157e+308
-- Smallest number = 2.2250738585072014e-308,
local MIN_NUMBER = -MAX_NUMBER
local MAX_INTEGER = 9007199254740992
local MIN_INTEGER = -MAX_INTEGER

---@class PropertyDef
local PropertyDef = {
    -- Assume text property by default (if no type is set)
    type = 'text',

    -- By default allow nulls
    minOccurrences = 0,

    -- By default scalar value
    maxOccurrences = 1
}

local propTypes;

-- Subclasses for specific property types
---@class BoolPropertyDef
local BoolPropertyDef = {}
setmetatable(BoolPropertyDef, PropertyDef)

-- Base property type for all range-able types
---@class NumberPropertyDef
local NumberPropertyDef = {}
setmetatable(BoolPropertyDef, PropertyDef)

---@class MoneyPropertyDef
local MoneyPropertyDef = {}
setmetatable(MoneyPropertyDef, NumberPropertyDef)

---@class IntegerPropertyDef
local IntegerPropertyDef = {}
setmetatable(IntegerPropertyDef, NumberPropertyDef)

---@class EnumPropertyDef
local EnumPropertyDef = {}
setmetatable(EnumPropertyDef, PropertyDef)

---@class DateTimePropertyDef
local DateTimePropertyDef = {}
setmetatable(DateTimePropertyDef, NumberPropertyDef)

---@class TimeSpanPropertyDef
local TimeSpanPropertyDef = {}
setmetatable(TimeSpanPropertyDef, DateTimePropertyDef)

---@class TextPropertyDef
local TextPropertyDef = {}
setmetatable(TextPropertyDef, PropertyDef)

---@class SymNamePropertyDef
local SymNamePropertyDef = {}
setmetatable(SymNamePropertyDef, TextPropertyDef)

---@class BlobPropertyDef
local BlobPropertyDef = {}
setmetatable(BlobPropertyDef, PropertyDef)

---@class UuidPropertyDef
local UuidPropertyDef = {}
setmetatable(UuidPropertyDef, BlobPropertyDef)

-- Base type for all reference-able properties
---@class MixinPropertyDef
local MixinPropertyDef = {}
setmetatable(MixinPropertyDef, PropertyDef)

---@class ReferencePropertyDef
local ReferencePropertyDef = {}
setmetatable(ReferencePropertyDef, MixinPropertyDef)

---@class NestedObjectPropertyDef
local NestedObjectPropertyDef = {}
setmetatable(NestedObjectPropertyDef, ReferencePropertyDef)

---@class ComputedPropertyDef
local ComputedPropertyDef = {}
setmetatable(ComputedPropertyDef, PropertyDef)

---@param self table @comment instance
---@return table @comment metatable of metatable of self
function PropertyDef:base()
    return getmetatable(getmetatable(self))
end

---@param ClassDef ClassDef
---@param json table @comment already parsed JSON
-- from class definition or separate property definition
function PropertyDef.fromJSON(ClassDef, json)
    return PropertyDef.loadFromDB(ClassDef, {}, json)
end

---@param ClassDef ClassDef
---@param obj table @comment [.class_props] row
---@param json table @comment Parsed json table, as a part of class definition
function PropertyDef.loadFromDB(ClassDef, obj, json)
    assert(ClassDef)

    -- name? id? nameid?

    local pt = propTypes[string.lower(json.type)]
    if not pt then
        error('Unknown property type ' .. json.type)
    end

    setmetatable(json, pt)
    pt.__index = pt

    obj.ClassDef = ClassDef
    obj.D = json
    return obj
end

--[[
Fields:
======
ClassID
ID
ctlvPlan
ctlv
Deleted?
PropNameID
LockedCol
D - json part

Methods:

canChangeTo
isValidDef
isValidData
save -- saves prop in database
toJSON
getNativeType
applyDef -- sets ctlv, ctlvPlan, name etc.

]]

--[[
===============================================================================
supportsRangeIndexing
===============================================================================
]]

function PropertyDef:supportsRangeIndexing()
    return false
end

---@overload
function NumberPropertyDef:supportsRangeIndexing()
    return true
end

--[[
===============================================================================
isValidDef
===============================================================================
]]

--- Common validation of property definition
-- raw table, decoded from JSON
---@return boolean, string @comment true if definition is valid, false if not and error message
-- true if propDef is valid; false otherwise
function PropertyDef:isValidDef()
    assert(self, 'Property not defined')

    -- Check common property settings
    -- minOccurrences & maxOccurences
    local minOccurrences = self.minOccurrences or 0
    local maxOccurrences = self.maxOccurrences or 1

    if type(minOccurrences) ~= 'number' or minOccurrences < 0 then
        return false, 'minOccurences must be a positive number'
    end

    if type(maxOccurrences) ~= 'number' or maxOccurrences < minOccurrences then
        return false, 'maxOccurrences must be a number greater or equal of minOccurrences'
    end

    return true
end

---
--- Checks if number property is well defined

---@overload
function NumberPropertyDef:isValidDef()
    local ok, errorMsg = self:base().isValidDef()
    if not ok then
        return ok, errorMsg
    end
    -- Check minValue and maxValue
    local maxV = tonumber(self.D.maxValue or MAX_NUMBER)
    local minV = tonumber(self.D.minValue or MIN_NUMBER)
    if minV > maxV then
        return false, 'Invalid minValue or maxValue settings'
    end

    return true
end

---@overload
function IntegerPropertyDef:isValidDef()
    local ok, errorMsg = self:base().isValidDef()
    if not ok then
        return ok, errorMsg
    end
    -- Check minValue and maxValue
    local maxV = math.min(tonumber(self.D.maxValue or MAX_INTEGER), MAX_INTEGER)
    local minV = math.max(tonumber(self.D.minValue or MIN_INTEGER), MIN_INTEGER)
    if minV > maxV then
        return false, 'Invalid minValue or maxValue settings'
    end

    return true
end

---@overload
function TextPropertyDef:isValidDef()
    local ok, errorMsg = self:base().isValidDef()
    if not ok then
        return ok, errorMsg
    end

    local maxL = tonumber(self.D.maxLength or 255)
    if maxL < 0 or maxL > 255 then
        return false, 'Invalid maxLength. Must be between 0 and 255'
    end

    -- TODO check regex

    return true
end

---@overload
function MixinPropertyDef:isValidDef()
    local ok, errorMsg = self:base().isValidDef()
    if not ok then
        return ok, errorMsg
    end

    -- Check referenced class definition

    return true
end

---@overload
function ReferencePropertyDef:isValidDef()
    local ok, errorMsg = self:base().isValidDef()
    if not ok then
        return ok, errorMsg
    end

    return true
end

---
--- Checks if enumeration is defined correctly
function EnumPropertyDef:isValidDef()
    local ok, errorMsg = self:base().isValidDef()
    if not ok then
        return ok, errorMsg
    end

    if type(self.D.enumDef) ~= 'table' then
        return false, 'enumDef is not defined or invalid'
    end

    -- name: NameRef
    -- items: table {value, text, icon}
    return true
end

--[[
===============================================================================
canChangeTo
===============================================================================
]]

-- Definite 'yes' is returned when a) propA.canChangeTo(propB) returned 'yes' and b) property types are compatible
-- and c) minOccurrences and maxOccurrences do not shrink
-- Definite 'no' is returned when propA does not support type change to propB or propA.canChangeTo(propB) returned 'no'
---@param DBContext DBContext
---@param propA PropertyDef
---@param propB PropertyDef
---@return string
-- 'yes', 'no', 'maybe' (=existing data validation needed)
function PropertyDef:canChangeTo(DBContext, self, another)
    assert(another)

    local result = 'yes'

    -- compare minOccurrences and maxOccurences to get preliminary verdict
    if self.minOccurrences or 0 < another.minOccurrences or 0 then
        result = 'maybe'
    elseif self.maxOccurrences or 0 < another.maxOccurrences or 0 then
        result = 'maybe'
    end

    return result
end

--[[
===============================================================================
save
===============================================================================
]]
function PropertyDef:save()
    assert(self.ClassDef and self.ClassDef.DBContext)

    local stmt = self.ClassDef.DBContext.getStatement [[

    ]]

    stmt:bind {}
    local result = stmt:step()
    if result ~= 0 then
        -- todo error
    end
end

--[[
===============================================================================
toJSON
===============================================================================
]]

---@return table @comment User friendly JSON-ready table with all public properties. Internal properties are not included
function PropertyDef:toJSON()
    local result = {
        name = self.Name,

    }

    -- TODO toJSON

    return result
end

--[[
===============================================================================
getNativeType
===============================================================================
]]
-- Returns native (SQLite) type, i.e. 'text', 'float', 'integer', 'blob'
---@return string
function PropertyDef:getNativeType()
    return ''
end

function NumberPropertyDef:getNativeType()
    return 'float'
end

function TextPropertyDef:getNativeType()
    return 'text'
end

function IntegerPropertyDef:getNativeType()
    return 'integer'
end

function BoolPropertyDef:getNativeType()
    return 'integer'
end

function BlobPropertyDef:getNativeType()
    return 'blob'
end

--[[
===============================================================================
applyDef

Applies property definition to the database. Called on property save
===============================================================================
]]
function PropertyDef:applyDef()

end

--[[
===============================================================================
hasUnresolvedReferences
===============================================================================
]]
function PropertyDef:hasUnresolvedReferences()
    return false
end

---@overload
function MixinPropertyDef:hasUnresolvedReferences()
    -- TODO
end

---@overload
function EnumPropertyDef:hasUnresolvedReferences()
    -- TODO
end



-- map for property types
propTypes = {
    ['bool'] = BoolPropertyDef,
    ['boolean'] = BoolPropertyDef,
    ['integer'] = IntegerPropertyDef,
    ['int'] = IntegerPropertyDef,
    ['number'] = NumberPropertyDef,
    ['float'] = NumberPropertyDef,
    ['text'] = TextPropertyDef,
    ['string'] = TextPropertyDef,
    ['bytes'] = BlobPropertyDef,
    ['binary'] = BlobPropertyDef,
    ['blob'] = BlobPropertyDef,
    ['decimal'] = MoneyPropertyDef,
    ['money'] = MoneyPropertyDef,
    ['uuid'] = UuidPropertyDef,
    ['enum'] = EnumPropertyDef,
    ['reference'] = ReferencePropertyDef,
    ['ref'] = ReferencePropertyDef,
    ['nested'] = NestedObjectPropertyDef,
    ['mixin'] = MixinPropertyDef,
    ['json'] = TextPropertyDef, -- TODO special prop type???
    ['computed'] = ComputedPropertyDef,
    ['formula'] = ComputedPropertyDef,
    ['name'] = SymNamePropertyDef,
    ['symname'] = SymNamePropertyDef,
    ['symbol'] = SymNamePropertyDef,
    ['date'] = DateTimePropertyDef,
    ['datetime'] = DateTimePropertyDef,
    ['time'] = DateTimePropertyDef,
    ['timespan'] = TimeSpanPropertyDef,
    ['duration'] = TimeSpanPropertyDef,
}

return PropertyDef