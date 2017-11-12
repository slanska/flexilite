---
--- Created by slanska.
--- DateTime: 2017-10-31 3:18 PM
---

--[[
Property definition
Keeps name, id, reference to class definition
Provides API for property definition validation, type change etc

Notes:
======
* PropertyDef is the base class for family of inherited classes
* PropertyDef has ClassDef to refer to the class-owner
* Concrete property class is determined by rules.type attribute
* Property gets created a) from class definition and db row (already initialized and validated)
or b) from JSON parsed to Lua table
* After creation, initRefs is called to set correct metatables for name/class/prop references
* isValidDef is used for self check - whether property definition is correct and complete
* isValidData is used for data validation, according to property rules
* meta attribute is used as-is. This is user defined data
* applyDef calculates ctlv flags and calls resolve for name/class/prop references. This will lead
to finding classes/properties/creating names etc. applyDefs is called after changes to class/property
definition
* canChangeTo checks if property definition can be changed. Result is 'yes' (upgrade), 'no' and
'maybe' (existing data need to be validated)
* import loads data from Lua table
* export return Lua table without internal properties and metatables

Flow for create class/property:
* set property metatable based on type
* initMetadataRefs - set metatable to metadata refs
* isValidDef - check if referenced properties exist etc
* applyDef - sets ctlv, ctlvPlan, create names, enum classes, reversed props
* saveToDB - inserts/updates .name_props table etc.
* hasUnresolvedReferences - checks if all referenced classes exist. Used for marking class unresolved

Flow for alter class/property:
* set new property metatable based on type
* initMetadataRefs - set metatable to metadata refs
* isValidDef - check if referenced properties exist etc
* canChangeTo - for alter operations
* if 'maybe' for at least one property - scan data, check isValidData
* applyDef (if alteration is OK)
* saveToDB
* ClassDef.rebuildIndexes - if new ctlv ~= old ctlv
* hasUnresolvedReferences

For resolve class:
* load from db, set new property metatable based on type
* initMetadataRefs - set metatable to metadata refs
* hasUnresolvedReferences
* if all refs are resolved, class is marked as resolved

]]

require 'math'
local bit = type(jit) == 'table' and require('bit') or require('bit32')
local NameRef, ClassNameRef, PropNameRef = require 'NameRef'
local EnumDef = require 'EnumDef'

-- Candidates for common.lua
local MAX_NUMBER = 1.7976931348623157e+308
-- Smallest number = 2.2250738585072014e-308,
local MIN_NUMBER = -MAX_NUMBER
local MAX_INTEGER = 9007199254740992
local MIN_INTEGER = -MAX_INTEGER

-- CTLV flags
local CTLV_FLAGS = {
    INDEX = 1,
    REF_STD = 3,
    -- 4(5) - ref: A -> B. When A deleted, delete B
    DELETE_B_WHEN_A = 5,
    -- 6(7) - when B deleted, delete A
    DELETE_A_WHEN_B = 7,
    -- 8(9) - when A or B deleted, delete counterpart
    DELETE_COUNTERPART = 9,
    --10(11) - cannot delete A until this reference exists
    CANNOT_DELETE_A_UNTIL_B = 11,
    --12(13) - cannot delete B until this reference exists
    CANNOT_DELETE_B_UNTIL_A = 13,
    --14(15) - cannot delete A nor B until this reference exist
    CANNOT_DELETE_UNTIL_COUNTERPART = 15,

    NAME_ID = 16,
    FTX_INDEX = 32,
    NO_TRACK_CHANGES = 64,
    UNIQUE = 128,
    DATE = 256,
    TIMESPAN = 512,
}

---@class PropertyDef
local PropertyDef = {
    rules = {
        -- Assume text property by default (if no type is set)
        type = 'text',

        -- By default allow nulls
        minOccurrences = 0,

        -- By default scalar value
        maxOccurrences = 1
    }
}

local propTypes;

-- Subclasses for specific property types
---@class BoolPropertyDef
local BoolPropertyDef = {}
setmetatable(BoolPropertyDef, PropertyDef)

-- Base property type for all range-able types
---@class NumberPropertyDef
local NumberPropertyDef = {}
setmetatable(NumberPropertyDef, PropertyDef)
NumberPropertyDef.__index = PropertyDef

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
DateTimePropertyDef.__index = NumberPropertyDef

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
---@param srcData table @comment already parsed source data
-- from class definition or separate property definition
function PropertyDef.import(ClassDef, srcData)
    return PropertyDef.loadFromDB(ClassDef, { }, srcData)
end

---@param ClassDef ClassDef
---@param obj table @comment [.class_props] row
---@param srcData table @comment Parsed json table, as a part of class definition
function PropertyDef.loadFromDB(ClassDef, obj, srcData)
    assert(ClassDef)
    assert(srcData and srcData.rules and srcData.rules.type)

    local pt = propTypes[string.lower(srcData.rules.type)]
    if not pt then
        error('Unknown property type ' .. srcData.type)
    end

    setmetatable(obj, pt)

    obj.ClassDef = ClassDef
    obj.D = srcData
    obj.Prop = { name = obj.Property, id = obj.NameID }
    setmetatable(obj.Prop, NameRef)

    obj:initMetadataRefs()

    return obj
end

--[[
===============================================================================
resolveReferences
===============================================================================
]]
function PropertyDef:initMetadataRefs()
    -- Do nothing
end

function MixinPropertyDef:initMetadataRefs()
    self:base().resolveReferences(self)

    if self.D and self.D.refDef and self.D.refDef.classRef then
        setmetatable(self.D.refDef.classRef, ClassNameRef)
    end
end

function ReferencePropertyDef:initMetadataRefs()
    self:base().resolveReferences(self)

    if self.D.refDef.reverseProperty then
        setmetatable(self.D.refDef.reverseProperty, PropNameRef)
    end

    if self.D and self.D.refDef and self.D.refDef.dynamic then
        if self.D.refDef.dynamic.selectorProp then
            setmetatable(self.D.refDef.dynamic.selectorProp, PropNameRef)
        end

        if self.D.refDef.dynamic.rules then
            for _, v in pairs(self.D.refDef.dynamic.rules) do
                if v and v.classRef then
                    setmetatable(v.classRef, ClassNameRef)
                end
            end
        end
    end
end

function EnumPropertyDef:initMetadataRefs()
    self:base().resolveReferences(self)

    if self.D.enumDef then
        if self.D.enumDef.classRef then
            setmetatable(self.D.enumDef.classRef, ClassNameRef)
        end

        if self.D.enumDef.items then
            for _, v in pairs(self.D.enumDef.items) do
                if v.name then
                    setmetatable(v.name, NameRef)
                end
            end
        end
    end
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
saveToDB
export
import
getNativeType
applyDef -- resolves references by names, sets ctlv, ctlvPlan, name etc.

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
    local minOccurrences = self.D.rules.minOccurrences or 0
    local maxOccurrences = self.D.rules.maxOccurrences or 1

    if type(minOccurrences) ~= 'number' or minOccurrences < 0 then
        return false, 'minOccurrences must be a positive number'
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
    local ok, errorMsg = self:base().isValidDef(self)
    if not ok then
        return ok, errorMsg
    end

    -- Check minValue and maxValue
    local maxV = tonumber(self.D.rules.maxValue or MAX_NUMBER)
    local minV = tonumber(self.D.rules.minValue or MIN_NUMBER)
    if minV > maxV then
        return false, 'Invalid minValue or maxValue settings'
    end

    return true
end

---@overload
function IntegerPropertyDef:isValidDef()
    local ok, errorMsg = self:base().isValidDef(self)
    if not ok then
        return ok, errorMsg
    end

    -- Check minValue and maxValue
    local maxV = math.min(tonumber(self.D.rules.maxValue or MAX_INTEGER), MAX_INTEGER)
    local minV = math.max(tonumber(self.D.rules.minValue or MIN_INTEGER), MIN_INTEGER)
    if minV > maxV then
        return false, 'Invalid minValue or maxValue settings'
    end

    return true
end

---@overload
function TextPropertyDef:isValidDef()
    local ok, errorMsg = self:base().isValidDef(self)
    if not ok then
        return ok, errorMsg
    end

    local maxL = tonumber(self.D.rules.maxLength or 0)
    if maxL < 0 then
        return false, 'Invalid maxLength. Must be non negative number'
    end

    -- TODO check regex

    return true
end

---@overload
function MixinPropertyDef:isValidDef()
    local ok, errorMsg = self:base().isValidDef(self)
    if not ok then
        return ok, errorMsg
    end

    -- Check referenced class definition
    if not self.D.refDef or not self.D.refDef.classRef then
        return false, 'Reference definition is invalid'
    end

    return true
end

---@overload
function ReferencePropertyDef:isValidDef()
    local ok, errorMsg = self:base().isValidDef(self)
    if not ok then
        return ok, errorMsg
    end

    -- Either class or rules must be defined
    if self.D.refDef and self.D.refDef.dynamic then
        if not self.D.refDef.dynamic.classRef and not self.D.refDef.dynamic.rules then
            return false, 'Either classRef or rules must be defined for dynamic reference'
        end

        if not self.D.refDef.dynamic.classRef and table.maxn(self.D.refDef.dynamic.rules) == 0 then
            return false, 'No rules defined for dynamic reference rules'
        end
    end

    return true
end

---
--- Checks if enumeration is defined correctly
function EnumPropertyDef:isValidDef()
    local ok, errorMsg = self:base().isValidDef(self)
    if not ok then
        return ok, errorMsg
    end

    if type(self.D.enumDef) ~= 'table' then
        return false, 'enumDef is not defined or invalid'
    end

    -- either classRef or items have to be defined
    if not self.D.enumDef.classRef and not self.D.enumDef.items then
        return false, 'enumDef must have either classRef or items or both'
    end

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
---@param another PropertyDef
---@return string
-- 'yes', 'no', 'maybe' (=existing data validation needed)
function PropertyDef:canChangeTo(another)
    assert(another)

    local result = 'yes'

    -- compare minOccurrences and maxOccurences to get preliminary verdict
    if self.D.rules.minOccurrences or 0 < another.D.rules.minOccurrences or 0 then
        result = 'maybe'
    elseif self.D.rules.maxOccurrences or 0 < another.D.rules.maxOccurrences or 0 then
        result = 'maybe'
    end

    return result
end

--[[
===============================================================================
saveToDB
===============================================================================
]]
---@param propId number
---@param propName string
function PropertyDef:saveToDB()
    assert(self.ClassDef and self.ClassDef.DBContext)

    assert(self.Prop and self.Prop:isResolved())

    local stmt = self.ClassDef.DBContext.getStatement [[
        insert or replace into [flexi_prop] (PropertyID, ClassID, NameID, ctlv, ctlvPlan)
        values (:1, :2, :3, :4, :5);
    ]]

    -- Detect column mapping

    stmt:bind { [1] = self.PropertyID, [2] = self.ClassDef.ClassID, [3] = self.Prop.id,
        [3] = self.ctlv, [4] = self.ctlvPlan }
    local result = stmt:step()
    if result ~= 0 then
        -- todo error
    end
end

--[[
===============================================================================
export
===============================================================================
]]

---@return table @comment User friendly JSON-ready table with all public properties.
-- Internal properties are not included
function PropertyDef:export()
    return self.D
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

function EnumPropertyDef:getNativeType()
    return 'text'
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
    -- resolve property name
    self.Prop:resolve(self.ClassDef)

    -- set ctlv
    self.ctlv = 0
    local idx = string.lower(self.D.index)
    if idx == 'index' then
        self.ctlv = bit.bor(self.ctlv, CTLV_FLAGS.INDEX)
    elseif idx == 'unique' then
        self.ctlv = bit.bor(self.ctlv, CTLV_FLAGS.UNIQUE)
    elseif idx == 'fulltext' then
        self.ctlv = bit.bor(self.ctlv, CTLV_FLAGS.FTX_INDEX)
    end

    if self.D.noTrackChanges then
        self.ctlv = bit.bor(self.ctlv, CTLV_FLAGS.NO_TRACK_CHANGES)
    end

    self.ctlvPlan = self.ctlv
end

function MixinPropertyDef:applyDef()
    self:base().applyDef(self)

    if self.D.refDef and self.D.refDef.classRef then
        self.D.refDef.classRef:resolve(self.ClassDef)
    end
end

function ReferencePropertyDef:applyDef()
    self:base().applyDef(self)

    if self.D.refDef then
        if self.D.refDef.reverseProperty then
            self.D.refDef.reverseProperty:resolve(self.ClassDef)
        end

        if self.D.refDef.dynamic then
            if self.D.refDef.dynamic.selectorProp then
                self.D.refDef.dynamic.selectorProp:resolve(self.ClassDef)
            end

            if self.D.refDef.dynamic.rules then
                for _, v in pairs(self.D.refDef.dynamic.rules) do
                    v.classRef:resolve(self.ClassDef)
                end
            end
        end
    end
end

function EnumPropertyDef:applyDef()
    self:base().applyDef(self)

    if self.D.enumDef then
        if self.D.enumDef.classRef then
            self.D.enumDef.classRef:resolve(self.ClassDef)
        end

        if self.D.enumDef.items then
            for _, v in pairs(self.D.enumDef.items) do
                v:resolve(self.ClassDef)
            end
        end
    end
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
    local result = self:base().hasUnresolvedReferences(self)
    if not result then
        return result
    end

    if self.D.refDef.classRef and not self.D.refDef.classRef:isResolved() then
        return false
    end

    return true
end

---@overload
function EnumPropertyDef:hasUnresolvedReferences()
    local result = self:base().hasUnresolvedReferences(self)
    if not result then
        return result
    end

    if self.D.enumDef then
        if not self.D.enumDef:isResolved() then
            return false
        end

        if self.D.enumDef.items then
            for _, v in pairs(self.D.enumDef.items) do
                if v.text and not v.text:isResolved() then
                    return false
                end
            end
        end
    end

    return true
end

---@overload
function ReferencePropertyDef:hasUnresolvedReferences()
    local result = self:base().hasUnresolvedReferences(self)
    if not result then
        return result
    end

    -- Check dynamic rules
    if self.D.refDef and self.D.refDef.dynamic then
        if self.D.refDef.dynamic.selectorProp
        and not self.D.refDef.dynamic.selectorProp:isResolved() then
            return false
        end

        if self.D.refDef.dynamic.rules then
            for _, v in pairs(self.D.refDef.dynamic.rules) do
                if v.classRef and not v.classRef:isResolved() then
                    return false
                end
            end
        end
    end

    return true
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