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

local class = require 'pl.class'
local tablex = require 'pl.tablex'
local schema = require 'schema'

-- TODO define schema for property definition
local propertySchema = schema.Record {
    rules = schema.Record {
        type = schema.OneOf('any', 'string', 'text'),

    }
}

require 'math'
local bit = type(jit) == 'table' and require('bit') or require('bit32')
local name_ref = require 'NameRef'
local EnumDef = require 'EnumDef'

local NameRef, ClassNameRef, PropNameRef = name_ref.NameRef, name_ref.ClassNameRef, name_ref.PropNameRef

-- Candidates for common.lua
local MAX_NUMBER = 1.7976931348623157e+308
-- Smallest number = 2.2250738585072014e-308,
local MIN_NUMBER = -MAX_NUMBER
local MAX_INTEGER = 9007199254740992
local MIN_INTEGER = -MAX_INTEGER

local MAX_BLOB_LENGTH = 1073741824

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

-- Forward declarations
local propTypes;

--[[
===============================================================================
PropertyDef
===============================================================================
]]

--- @class PropertyDef
local PropertyDef = class()

function PropertyDef.CreateInstance(classDef, srcData)
    local pt = propTypes[string.lower(srcData.rules.type)]
    if not pt then
        error('Unknown property type ' .. srcData.type)
    end

    local result = pt(classDef, srcData)
    return result
end

-- PropertyDef constructor
function PropertyDef:_init(ClassDef, srcData)
    assert(ClassDef)
    assert(srcData and srcData.rules and srcData.rules.type)

    --self.rules = {
    --    -- Assume text property by default (if no type is set)
    --    type = 'text',
    --
    --    -- By default allow nulls
    --    minOccurrences = 0,
    --
    --    -- By default scalar value
    --    maxOccurrences = 1
    --}

    self.ClassDef = ClassDef
    self.D = srcData
    self.Prop = NameRef(self.Property, self.NameID)
    self:initMetadataRefs()
end

function PropertyDef:hasUnresolvedReferences()
    return false
end

function PropertyDef:initMetadataRefs()
    -- Do nothing
end

function PropertyDef:ColumnMappingSupported()
    return true
end

-- true if property value can be used as user defined ID (UID)
function PropertyDef:CanBeUsedAsUID()
    return true
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
ColMap
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

function PropertyDef:supportsRangeIndexing()
    return false
end

--- Common validation of property definition
-- raw table, decoded from JSON
--- @return boolean, string @comment true if definition is valid, false if not and error message
-- true if propDef is valid; false otherwise
function PropertyDef:isValidDef()
    assert(self, 'Property not defined')

    --TODO check property name

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

-- Definite 'yes' is returned when a) propA.canChangeTo(propB) returned 'yes' and b) property types are compatible
-- and c) minOccurrences and maxOccurrences do not shrink
-- Definite 'no' is returned when propA does not support type change to propB or propA.canChangeTo(propB) returned 'no'
--- @param another PropertyDef
--- @return string
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

--- @param propId number
--- @param propName string
function PropertyDef:saveToDB()
    assert(self.ClassDef and self.ClassDef.DBContext)

    assert(self.Prop and self.Prop:isResolved())

    if self.ID and tonumber(self.ID) > 0 then
        -- Update existing
        self.ClassDef.DBContext:execStatement([[update [.class_props]
        set NameID = :nameID, ctlv = :ctlv, ctlvPlan = :ctlvPlan, ColMap = :ColMap
        where ID = :id]],
        {
            nameID = self.Prop.id,
            ctlv = self.ctlv,
            ctlvPlan = self.ctlvPlan,
            ColMap = self.ColMap,
            id = self.PropertyID
        })
    else
        -- Insert new
        self.ClassDef.DBContext:execStatement(
        [[insert into [.class_props] (ClassID, NameID, ctlv, ctlvPlan, ColMap)
            values (:ClassID, :NameID, :ctlv, :ctlvPlan, :ColMap);]], {
            ClassID = self.ClassDef.ClassID,
            NameID = self.Prop.id,
            ctlv = self.ctlv,
            ctlvPlan = self.ctlvPlan,
            ColMap = self.ColMap
        })

        self.PropertyID = self.ClassDef.DBContext.db:last_insert_rowid()
    end

    return self.PropertyID
end

--- @return table @comment User friendly JSON-ready table with all public properties.
-- Internal properties are not included
function PropertyDef:export()
    return self.D
end

-- Returns native (SQLite) type, i.e. 'text', 'float', 'integer', 'blob'
--- @return string
function PropertyDef:getNativeType()
    return ''
end

--Applies property definition to the database. Called on property save
function PropertyDef:applyDef()
    -- resolve property name
    self.Prop:resolve(self.ClassDef)

    -- set ctlv
    self.ctlv = 0
    local idx = string.lower(self.D.index or '')
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

--- Returns table representation of property definition as it will be used for class definition
--- serialization to JSON
---@return table
function PropertyDef:internalToJSON()
    return tablex.deepcopy(self.D)
end

--[[
===============================================================================
NumberPropertyDef
===============================================================================
]]

-- Base property type for all range-able types
--- @class NumberPropertyDef
local NumberPropertyDef = class(PropertyDef)

function NumberPropertyDef:_init(classDef, srcData)
    self:super(classDef, srcData)
end

-- Checks if number property is well defined
--- @overload
function NumberPropertyDef:isValidDef()
    local ok, errorMsg = PropertyDef.isValidDef(self)
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

function NumberPropertyDef:getNativeType()
    return 'float'
end

--- @overload
function NumberPropertyDef:supportsRangeIndexing()
    return true
end

--[[
===============================================================================
MoneyPropertyDef
===============================================================================
]]
--- @class MoneyPropertyDef
local MoneyPropertyDef = class(NumberPropertyDef)

function MoneyPropertyDef:_init(classDef, srcData)
    self:super(classDef, srcData)
end

-- TODO

--[[
===============================================================================
IntegerPropertyDef
===============================================================================
]]

--- @class IntegerPropertyDef
local IntegerPropertyDef = class(NumberPropertyDef)

function IntegerPropertyDef:_init(classDef, srcData)
    self:super(classDef, srcData)
end

--- @overload
function IntegerPropertyDef:isValidDef()
    local ok, errorMsg = NumberPropertyDef.isValidDef(self)
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

function IntegerPropertyDef:getNativeType()
    return 'integer'
end

--[[
===============================================================================
TextPropertyDef
===============================================================================
]]

--- @class TextPropertyDef
local TextPropertyDef = class(PropertyDef)

function TextPropertyDef:_init(classDef, srcData)
    self:super(classDef, srcData)
end

--- @overload
function TextPropertyDef:isValidDef()
    local ok, errorMsg = PropertyDef.isValidDef(self)
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

function TextPropertyDef:getNativeType()
    return 'text'
end

function TextPropertyDef:ColumnMappingSupported()
    return (self.D.rules.maxLength or 255) <= 255
end

--[[
===============================================================================
SymNamePropertyDef
===============================================================================
]]

--- @class SymNamePropertyDef
local SymNamePropertyDef = class(TextPropertyDef)

function SymNamePropertyDef:_init(classDef, srcData)
    self:super(classDef, srcData)
end

function SymNamePropertyDef:ColumnMappingSupported()
    return true
end

--[[
===============================================================================
MixinPropertyDef
===============================================================================
]]

-- Base type for all reference-able properties
--- @class MixinPropertyDef
local MixinPropertyDef = class(PropertyDef)

function MixinPropertyDef:_init(classDef, srcData)
    self:super(classDef, srcData)
end

--- @overload
function MixinPropertyDef:isValidDef()
    local ok, errorMsg = PropertyDef.isValidDef(self)
    if not ok then
        return ok, errorMsg
    end

    -- Check referenced class definition
    if not self.D.refDef or not self.D.refDef.classRef then
        return false, 'Reference definition is invalid'
    end

    return true
end

function MixinPropertyDef:applyDef()
    PropertyDef.applyDef(self)

    if self.D.refDef and self.D.refDef.classRef then
        self.D.refDef.classRef:resolve(self.ClassDef)
    end
end

--- @overload
function MixinPropertyDef:hasUnresolvedReferences()
    local result = PropertyDef.hasUnresolvedReferences(self)
    if not result then
        return result
    end

    if self.D.refDef.classRef and not self.D.refDef.classRef:isResolved() then
        return false
    end

    return true
end

function MixinPropertyDef:initMetadataRefs()
    PropertyDef.initMetadataRefs(self)

    if self.D and self.D.refDef and self.D.refDef.classRef then
        setmetatable(self.D.refDef.classRef, ClassNameRef)
    end
end

-- Returns internal JSON representation of property
function MixinPropertyDef:internalToJSON()
    local result = PropertyDef.internalToJSON(self)

    result.refDef = tablex.deepcopy(self.refDef)

    return result
end

function PropertyDef:ColumnMappingSupported()
    return false
end

-- true if property value can be used as user defined ID (UID)
function PropertyDef:CanBeUsedAsUID()
    return false
end

--[[
===============================================================================
ReferencePropertyDef
===============================================================================
]]

--- @class ReferencePropertyDef
local ReferencePropertyDef = class(MixinPropertyDef)

function ReferencePropertyDef:_init(classDef, srcData)
    self:super(classDef, srcData)
end

--- @overload
function ReferencePropertyDef:isValidDef()
    local ok, errorMsg = MixinPropertyDef.isValidDef(self)
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

function ReferencePropertyDef:initMetadataRefs()
    MixinPropertyDef.initMetadataRefs(self)

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

--- @overload
function ReferencePropertyDef:hasUnresolvedReferences()
    local result = MixinPropertyDef.hasUnresolvedReferences(self)
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

function ReferencePropertyDef:applyDef()
    MixinPropertyDef.applyDef(self)

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

--[[
===============================================================================
NestedObjectPropertyDef
===============================================================================
]]

--- @class NestedObjectPropertyDef
local NestedObjectPropertyDef = class(ReferencePropertyDef)

function NestedObjectPropertyDef:_init(classDef, srcData)
    self:super(classDef, srcData)
end

--[[
===============================================================================
EnumPropertyDef
===============================================================================
]]

--- @class EnumPropertyDef
local EnumPropertyDef = class(PropertyDef)

function EnumPropertyDef:_init(classDef, srcData)
    self:super(classDef, srcData)
end

---
--- Checks if enumeration is defined correctly
function EnumPropertyDef:isValidDef()
    local ok, errorMsg = PropertyDef.isValidDef(self)
    if not ok then
        return ok, errorMsg
    end

    local enumDef = self.D.enumDef or self.D.refDef
    if type(enumDef) ~= 'table' then
        return false, 'enumDef nor refDef is not defined or invalid'
    end

    -- either classRef or items have to be defined
    if not enumDef.classRef and not enumDef.items then
        return false, 'enumDef must have either classRef or items or both'
    end

    return true
end

function EnumPropertyDef:getNativeType()
    return 'text'
end

--- @overload
function EnumPropertyDef:hasUnresolvedReferences()
    local result = PropertyDef.hasUnresolvedReferences(self)
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

function EnumPropertyDef:applyDef()
    PropertyDef.applyDef(self)

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

function EnumPropertyDef:internalToJSON()
    local result = PropertyDef.internalToJSON(self)

    result.refDef = tablex.deepcopy(self.enumDef)

    return result
end

function EnumPropertyDef:initMetadataRefs()
    PropertyDef.initMetadataRefs(self)

    if self.D.enumDef then
        if self.D.enumDef.classRef then
            setmetatable(self.D.enumDef.classRef, ClassNameRef)
        end

        if self.D.enumDef.items then
            local newItems = {}
            for i, v in pairs(self.D.enumDef.items) do
                if v and v.text then
                    newItems[1] = NameRef(v.text, v.id)
                end
            end
            self.D.enumDef.items = newItems
        end
    end
end

-- true if property value can be used as user defined ID (UID)
function EnumPropertyDef:CanBeUsedAsUID()
    return false
end

--[[
===============================================================================
BoolPropertyDef
===============================================================================
]]
--- @class BoolPropertyDef
local BoolPropertyDef = class(PropertyDef)

function BoolPropertyDef:_init(classDef, srcData)
    self:super(classDef, srcData)
end

function BoolPropertyDef:getNativeType()
    return 'integer'
end

-- true if property value can be used as user defined ID (UID)
function BoolPropertyDef:CanBeUsedAsUID()
    return false
end

--[[
===============================================================================
BlobPropertyDef
===============================================================================
]]

--- @class BlobPropertyDef
local BlobPropertyDef = class(PropertyDef)

function BlobPropertyDef:_init(classDef, srcData)
    self:super(classDef, srcData)
end

function BlobPropertyDef:getNativeType()
    return 'blob'
end

function BlobPropertyDef:ColumnMappingSupported()
    return (self.D.rules.maxLength or MAX_BLOB_LENGTH) <= 255
end

-- true if property value can be used as user defined ID (UID)
function BlobPropertyDef:CanBeUsedAsUID()
    return false
end

--[[
===============================================================================
UuidPropertyDef
===============================================================================
]]

--- @class UuidPropertyDef
local UuidPropertyDef = class(BlobPropertyDef)

function UuidPropertyDef:_init(classDef, srcData)
    self:super(classDef, srcData)
end

--[[
===============================================================================
DateTimePropertyDef
===============================================================================
]]

--- @class DateTimePropertyDef
local DateTimePropertyDef = class(NumberPropertyDef)

function DateTimePropertyDef:_init(classDef, srcData)
    self:super(classDef, srcData)
end

--[[
===============================================================================
TimeSpanPropertyDef
===============================================================================
]]

--- @class TimeSpanPropertyDef
local TimeSpanPropertyDef = class(DateTimePropertyDef)

function TimeSpanPropertyDef:_init(classDef, srcData)
    self:super(classDef, srcData)
end

--[[
===============================================================================
ComputedPropertyDef
===============================================================================
]]

--- @class ComputedPropertyDef
local ComputedPropertyDef = class(PropertyDef)

function ComputedPropertyDef:_init(classDef, srcData)
    self:super(classDef, srcData)
end


function ComputedPropertyDef:ColumnMappingSupported()
    return false
end

-- true if property value can be used as user defined ID (UID)
function ComputedPropertyDef:CanBeUsedAsUID()
    return false
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