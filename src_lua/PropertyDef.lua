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

-- Static methods

--- Common validation of property definition
---@param DBContext DBContext
---@param propDef PropertyDef
-- raw table, decoded from JSON
---@return boolean
-- true if propDef is valid; false otherwise
function PropertyDef.validate(DBContext, propDef)
    assert(propDef, 'Property not defined')

    -- If not defined assume 'text' type
    local ptype = propDef.type or 'text'

    -- Check common property settings
    -- minOccurrences & maxOccurences
    local minOccurrences = propDef.minOccurrences or 0
    local maxOccurrences = propDef.maxOccurrences or 1

    if type(minOccurrences) ~= 'number' or minOccurrences < 0 then
        error('minOccurences must be a positive number')
    end

    if type(maxOccurrences) ~= 'number' or maxOccurences < minOccurrences then
        error('maxOccurrences must be a number greater or equal of minOccurrences')
    end

    local pp = propTypes[ptype]
    if not pp or not pp.isValidDef then
        error('Unknown or incomplete property type: ' .. ptype)
    end

    return pp.isValidDef(pp)
end

-- Definite 'yes' is returned when a) propA.canChangeTo(propB) returned 'yes' and b) property types are compatible
-- and c) minOccurrences and maxOccurrences do not shrink
-- Definite 'no' is returned when propA does not support type change to propB or propA.canChangeTo(propB) returned 'no'
---@param DBContext DBContext
---@param propA PropertyDef
---@param propB PropertyDef
---@return string
-- 'yes', 'no', 'maybe' (=existing data validation needed)
function PropertyDef.canChangeTo(DBContext, propA, propB)
    assert(propA)
    assert(propB)

    local result = 'no'

    local srcPType = propA.type or 'text'
    local destPType = propA.type or 'text'
    local srcPTbl = propTypes[srcPType]
    local destPTbl = propTypes[destPType]

    assert(srcPTbl)
    assert(destPTbl)

    -- compare minOccurrences and maxOccurences to get preliminary verdict
    if propA.minOccurrences or 0 < propB.minOccurrences or 0 then
        result = 'maybe'
    elseif propA.maxOccurrences or 0 < propB.maxOccurrences or 0 then
        result = 'maybe'
    end


    -- if property tables are the same or compatible, need to check minOccurrences and maxOccurences
    if srcPTbl.baseType == destPTbl.baseType then

    end

    return result
end

--- Creates new instance of PropertyDef, assigned to ClassDef
---@param ClassDef ClassDef
---@param name string
---@return PropertyDef
function PropertyDef:new(ClassDef, name)
    local result = {
        ClassDef = ClassDef,
        name = name
    }

    setmetatable(result, self)
    self.__index = self

    return result
end

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

function PropertyDef:selfValidate()
    -- todo
end

---@return table @comment User friendly JSON-ready table with all public properties. Internal properties are not included
function PropertyDef:toJSON()
    local result = {
        name = self.Name,

    }

    -- TODO toJSON

    return result
end

--[[
Property type is defined as table of the following structure:
canChangeTo(newPropertyDef) -> 'yes', 'no', 'maybe' (data scan and validation needed)
isValidDef() -> bool
apply() [optional] applies definition (create index etc.)
baseType string
mayUpgradeTo: array of string
]]

local BooleanType = {
    baseType = 'boolean',

    mayUpgradeTo = { 'integer' },

    canChangeTo = function(self, newPropertyDef)
        -- YES: integer, number, text, symname, enum?
        -- NO: reference, mixin, date*

    end,

    isValidDef = function(self)
        return true
    end,

    apply = function(self)

    end
}

local IntegerType = {
    baseType = 'integer',

    mayUpgradeTo = { 'number', 'enum' },

    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

local NumberType = {
    baseType = 'number',

    mayUpgradeTo = { 'text', 'date' },

    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

local TextType = {
    baseType = 'text',

    mayUpgradeTo = { 'symname', 'reference', 'computed' },

    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)
        -- create index: unique, normal, full text
    end
}

local DateTimeType = {
    baseType = 'date',

    mayUpgradeTo = { 'text', 'number' },

    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

local UuidType = {
    baseType = 'uuid',

    mayUpgradeTo = { 'text', 'blob' },

    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

local BytesType = {
    baseType = 'blob',

    mayUpgradeTo = { 'text' },

    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

local EnumType = {
    baseType = 'reference',

    mayUpgradeTo = { 'integer', 'text' },

    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)
        -- create new or find existing enum def
    end
}

local ReferenceType = {
    baseType = 'reference',

    mayUpgradeTo = {},

    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)
        assert(self and self.ClassDef and self.ClassDef.DBContext)
        -- ensures that all
    end
}

local NestedType = {
    baseType = 'reference',

    mayUpgradeTo = { 'reference' },

    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)
        -- mixin class name is a valid identifier
    end,

    apply = function(self)
        -- create class if needed
    end
}

local MixinType = {
    baseType = 'mixin',

    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)
        -- mixin class name is a valid identifier
    end,

    apply = function(self)
        -- create empty class if it is not defined
    end
}

local SymNameType = {
    baseType = 'text',

    mayUpgradeTo = { 'text' },

    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)
        -- maxLength, regex
    end,

    apply = function(self)

    end
}

local MoneyType = {
    baseType = 'number',

    mayUpgradeTo = { 'text' },

    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)
        -- minValue and maxValue
    end,

    apply = function(self)

    end
}

local JsonType = {
    baseType = 'text',

    mayUpgradeTo = { 'blob', 'reference', 'nested' },

    canChangeTo = function(self, newPropertyDef)
        -- text, reference, blob
    end,

    isValidDef = function(self)
        -- maxOccurrences is ignored
        -- maxLength used for limiting JSON length
    end,

    apply = function(self)

    end
}

local ComputedType = {
    baseType = 'computed',

    canChangeTo = function(self, newPropertyDef)
        -- can be changed to text (formula body)
    end,

    isValidDef = function(self)
        -- parses formula (in Lua language)
        -- maxOccurrences, maxLength are ignored
    end,

    apply = function(self)
        -- TODO Compute?
    end
}

-- map for property types
propTypes = {
    ['bool'] = BooleanType,
    ['boolean'] = BooleanType,
    ['integer'] = IntegerType,
    ['int'] = IntegerType,
    ['number'] = NumberType,
    ['float'] = NumberType,
    ['text'] = TextType,
    ['string'] = TextType,
    ['bytes'] = BytesType,
    ['binary'] = BytesType,
    ['blob'] = BytesType,
    ['bytes'] = BytesType,
    ['decimal'] = MoneyType,
    ['money'] = MoneyType,
    ['uuid'] = UuidType,
    ['enum'] = EnumType,
    ['reference'] = ReferenceType,
    ['ref'] = ReferenceType,
    ['nested'] = NestedType,
    ['mixin'] = MixinType,
    ['json'] = JsonType,
    ['computed'] = ComputedType,
    ['formula'] = ComputedType,
    ['name'] = SymNameType,
    ['symname'] = SymNameType,
    ['symbol'] = SymNameType,
    ['date'] = DateTimeType,
    ['datetime'] = DateTimeType,
    ['time'] = DateTimeType,
    ['timespan'] = DateTimeType,

}

return PropertyDef