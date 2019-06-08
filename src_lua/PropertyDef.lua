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
local class = require 'pl.class'
local tablex = require 'pl.tablex'
local schema = require 'schema'
local bit = type(jit) == 'table' and require('bit') or require('bit32')
local name_ref = require 'NameRef'
local NameRef, ClassNameRef, PropNameRef = name_ref.NameRef, name_ref.ClassNameRef, name_ref.PropNameRef
local Constants = require 'Constants'
local AccessControl = require 'AccessControl'
local dbprops = require 'DBProperty'
local parseDateTimeToJulian = require('Util').parseDateTimeToJulian
local stringifyDateTimeInfo = require('Util').stringifyDateTimeInfo
local base64 = require 'base64'

--[[
===============================================================================
PropertyDef
===============================================================================
]]

-- TODO Define classes to rules, enumDef, refDef etc.

---@class PropertyRules
---@field type string
---@field maxLength number
---@field maxOccurrences number
---@field minOccurrences number
---@field maxValue number
---@field minValue number

---@class PropertyEnumDef
---@field items table @comment EnumItemDef[]

---@class PropertyDefData
---@field rules PropertyRules
---@field enumDef PropertyEnumDef
---@field refDef table
---@field accessRules table
---@field indexing string
---@field defaultValue any

---@class PropertyDefCtorParams
---@field ClassDef ClassDef
---@field newPropertyName string
---@field jsonData PropertyDefData
---@field dbrow table @comment [flexi_prop] structure

---@class PropertyDef
---@field ID number
---@field ClassDef ClassDef
---@field D PropertyDefData @comment parsed property definition JSON
---@field Name NameRef
---@field ctlv number
---@field ctlvPlan number
---@field Deleted boolean
---@field ColMap string
---@field NonNullCount number
---@field SearchHitCount number
local PropertyDef = class()

-- Factory method to create a property object based on rules.type in params.jsonData
---@param params PropertyDefCtorParams @comment 2 variants:
---for new property (not stored in DB) {ClassDef: ClassDef, newPropertyName:string, jsonData: table}
---for existing property (when loading from DB): {ClassDef: ClassDef, dbrow: table, jsonData: table}
function PropertyDef.CreateInstance(params)
    local propCtor = PropertyDef.PropertyTypes[string.lower(params.jsonData.rules.type)]
    if not propCtor then
        error('Unknown property type ' .. params.jsonData.rules.type)
    end

    return propCtor(params)
end

-- PropertyDef constructor
---@param params PropertyDefCtorParams @comment 2 variants:
---for new property (not stored in DB) {ClassDef: ClassDef, newPropertyName:string, jsonData: table}
---for existing property (when loading from DB): {ClassDef: ClassDef, dbrow: table, jsonData: table}
function PropertyDef:_init(params)
    assert(params.ClassDef)
    assert(params.jsonData and params.jsonData.rules and params.jsonData.rules.type)

    ---@type ClassDef
    self.ClassDef = params.ClassDef
    self.D = params.jsonData

    if params.newPropertyName then
        -- New property, no row in database, no resolved name IDs
        ---@type NameRef
        self.Name = NameRef(params.newPropertyName)
        self:initMetadataRefs()
    else
        assert(params.dbrow)
        assert(params.jsonData)

        self.Name = NameRef(params.dbrow.Property, params.dbrow.NameID)

        -- Copy property attributes
        ---@type number
        self.ID = params.dbrow.PropertyID
        self.ctlv = params.dbrow.ctlv or 0
        self.ctlvPlan = params.dbrow.ctlvPlan or 0
        self.Deleted = params.dbrow.Deleted or false
        self.ColMap = params.dbrow.ColMap
        self.NonNullCount = params.dbrow.NonNullCount or 0
        self.SearchHitCount = params.dbrow.SearchHitCount or 0

        self.ClassDef.DBContext.ClassProps[self.ID] = self
    end
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

function PropertyDef:supportsRangeIndexing()
    return false
end

-- Definite 'yes' is returned when a) propA.canChangeTo(propB) returned 'yes' and b) property types are compatible
-- and c) minOccurrences and maxOccurrences do not shrink
-- Definite 'no' is returned when propA does not support type change to propB or propA.canChangeTo(propB) returned 'no'
--- @param another PropertyDef
--- @return string
-- 'yes', 'no', 'maybe' (=existing data validation needed)
function PropertyDef:canAlterDefinition(newDef)
    assert(newDef)

    local result = 'yes'

    -- compare minOccurrences and maxOccurences to get preliminary verdict
    if self.D.rules.minOccurrences or 0 < newDef.D.rules.minOccurrences or 0 then
        result = 'maybe'
    elseif self.D.rules.maxOccurrences or 0 < newDef.D.rules.maxOccurrences or 0 then
        result = 'maybe'
    end

    return result
end

--- @param propId number
--- @param propName string
function PropertyDef:saveToDB()
    assert(self.ClassDef and self.ClassDef.DBContext)

    assert(self.Name and self.Name:isResolved())

    -- Set ctlv
    self.ctlv = self:GetCTLV()

    if self.ID and tonumber(self.ID) > 0 then
        -- Update existing
        self.ClassDef.DBContext:execStatement([[update [.class_props]
        set NameID = :nameID, ctlv = :ctlv, ctlvPlan = :ctlvPlan, ColMap = :ColMap
        where ID = :id]],
                {
                    nameID = self.Name.id,
                    ctlv = self.ctlv,
                    ctlvPlan = self.ctlvPlan,
                    ColMap = self.ColMap,
                    id = self.ID
                })
    else
        -- Insert new
        self.ClassDef.DBContext:execStatement(
                [[insert into [.class_props] (ClassID, NameID, ctlv, ctlvPlan, ColMap)
                    values (:ClassID, :NameID, :ctlv, :ctlvPlan, :ColMap);]], {
                    ClassID = self.ClassDef.ClassID,
                    NameID = self.Name.id,
                    ctlv = self.ctlv,
                    ctlvPlan = self.ctlvPlan,
                    ColMap = self.ColMap
                })

        self.ID = self.ClassDef.DBContext.db:last_insert_rowid()

        -- As property ID is now known, register property in DBContext property collection
        self.ClassDef.DBContext.ClassProps[self.ID] = self

        local key = string.format('%s.%s', self.ClassDef.Name.text, self.Name.text)
        self.ClassDef.DBContext:ResolveDeferredRefs(key, self.ID)
    end

    return self.ID
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

-- Builds bit flag value for [.ref-value].ctlv field
---@return number
function PropertyDef:GetCTLV()
    local result = self:GetVType()
    local idxType = string.lower(self.D.index or '')
    if idxType == 'index' then
        result = bit.bor(result, Constants.CTLV_FLAGS.INDEX)
    elseif idxType == 'unique' then
        result = bit.bor(result, Constants.CTLV_FLAGS.UNIQUE)
    else
        result = bit.band(result, bit.bnot(bit.bor(Constants.CTLV_FLAGS.INDEX, Constants.CTLV_FLAGS.UNIQUE)))
    end

    if self.D.noTrackChanges then
        result = bit.bor(result, Constants.CTLV_FLAGS.NO_TRACK_CHANGES)
    end

    return result
end

--Applies property definition to the database. Called on property save
function PropertyDef:applyDef()
    -- resolve property name
    self.Name:resolve(self.ClassDef)
    self.ctlv = self:GetCTLV()
    self.ctlvPlan = self.ctlv
end

--- Returns table representation of property definition as it will be used for class definition
--- serialization to JSON
---@return table
function PropertyDef:internalToJSON()
    return tablex.deepcopy(self.D)
end

function PropertyDef:isReference()
    return false
end

---@return number
function PropertyDef:GetVType()
    return Constants.vtype.default
end

function PropertyDef:buildValueSchema(valueSchema)
    local s = { valueSchema }
    local maxOccurr = (self.D.rules and self.D.rules.maxOccurrences) or 1
    if maxOccurr > 1 then
        -- collection
        s[2] = schema.Collection(valueSchema)
    else
        -- one item tuple
        s[2] = schema.Tuple(valueSchema)
    end

    local minOccurr = (self.D.rules and self.D.rules.minOccurrences) or 0
    if minOccurr == 0 then
        s[3] = schema.Nil
    end

    return schema.OneOf(unpack(s))
end

---@param op string @comment 'C' or 'U'
function PropertyDef:GetValueSchema(op)
    return schema.Any
end

function PropertyDef:GetSupportedIndexTypes()
    return Constants.INDEX_TYPES.NON
end

-- Returns column expression to access property value (with PropIndex = 1)
-- Used to build dynamic SQL
---@param first boolean @comment if true, will preprend column expression with comma
---@return string
function PropertyDef:GetColumnExpression(first)
    if self.ColMap then
        return string.format(
                '%s coalesce([%s], (select [Value] from [.ref-values] where ClassID=%d and PropertyID=%d and PropIndex=0 limit 1)) as [%s]',
                first and ' ' or ',', self.ColMap, self.ClassDef.ClassID, self.ID, self.Name.text)
    else
        return string.format(
                '%s (select [Value] from [.ref-values] where ClassID=%d and PropertyID=%d and PropIndex=0 limit 1) as [%s]',
                first and '' or ',', self.ClassDef.ClassID, self.ID, self.Name.text)
    end
end

-- Creates instance of DBProperty for DBObject
---@param object DBObject
function PropertyDef:CreateDBProperty(object)
    local result = dbprops.DBProperty(object, self)
    return result
end

-- Converts value from user format to internally used storage format
---@param dbv DBValue
---@return any
function PropertyDef:GetRawValue(dbv)
    return dbv.Value
end

---@param dbv DBValue
---@param val any
function PropertyDef:SetRawValue(dbv, val)
    dbv.Value = val
end

-- Sets dbv.Value from source data v, with possible conversion and/or validation
---@param dbv DBValue
---@param v any
function PropertyDef:ImportDBValue(dbv, v)
    dbv.Value = v
end

-- Converts dbv.Value to the format, appropriate for JSON serialization
---@param dbo DBObject
---@param dbv DBValue
---@return any
function PropertyDef:ExportDBValue(dbo, dbv)
    return dbv.Value
end

-- Binds Value parameter to insert/update .ref-values
---@param stmt sqlite3_statement
---@param param_no number
---@param dbv DBValue
function PropertyDef:BindValueParameter(stmt, param_no, dbv)
    stmt:bind(param_no, dbv.Value)
end

--[[ Called before .ref-value row is inserted/updated
Returns tuple of 2 values: boolean and function
If boolean is true, .ref-values row gets inserted/updated immediately.
Otherwise, update operation is skipped at this time
If function part is not nil, it gets added to deferredActions list to be called when all objects in batch are inserted/updated

Possible combinations:
true, nil - normal scalar value, gets inserted/updated immediately
true, function - value gets inserted/updated, and also deferred action gets registered
false, nil - no-op
false, function - typically, reference. No .ref-values row is inserted/updated and deferred action is registered
]]
---@return boolean, function
function PropertyDef:BeforeDBValueSave(dbv)
    return true, nil
end

-- Returns index of column mapped
---@return number | nil
function PropertyDef:ColMapIndex()
    return self.ColMap ~= nil and string.lower(self.ColMap):byte() - string.byte('a') or nil
end

--[[
===============================================================================
AnyPropertyDef
===============================================================================
]]

local AnyPropertyDef = class(PropertyDef)

function AnyPropertyDef:_init(params)
    self:super(params)
end

-- TODO override methods, allow any data??

--[[
===============================================================================
NumberPropertyDef
===============================================================================
]]

-- Base property type for all range-able types
--- @class NumberPropertyDef
local NumberPropertyDef = class(PropertyDef)

function NumberPropertyDef:_init(params)
    self:super(params)
end

-- Checks if number property is well defined
--- @overload
--function NumberPropertyDef:isValidDef()
--    local ok, errorMsg = PropertyDef.isValidDef(self)
--    if not ok then
--        return ok, errorMsg
--    end
--
--    -- Check minValue and maxValue
--    local maxV = tonumber(self.D.rules.maxValue or Constants.MAX_NUMBER)
--    local minV = tonumber(self.D.rules.minValue or Constants.MIN_NUMBER)
--    if minV > maxV then
--        return false, 'Invalid minValue or maxValue settings'
--    end
--
--    return true
--end

function NumberPropertyDef:getNativeType()
    return 'float'
end

--- @overload
function NumberPropertyDef:supportsRangeIndexing()
    return true
end

---@param op string @comment 'C' or 'U'
function NumberPropertyDef:GetValueSchema(op)
    local result = self:buildValueSchema(
            schema.NumberFrom(self.D.rules.minValue or Constants.MIN_NUMBER,
                    self.D.rules.maxValue or Constants.MAX_NUMBER))
    return result
end

function NumberPropertyDef:GetSupportedIndexTypes()
    return Constants.INDEX_TYPES.MUL + Constants.INDEX_TYPES.RNG + Constants.INDEX_TYPES.STD + Constants.INDEX_TYPES.UNQ
end

---@param dbv DBValue
---@param v any
function NumberPropertyDef:ImportDBValue(dbv, v)
    dbv.Value = tonumber(v)
end

--[[
===============================================================================
MoneyPropertyDef
===============================================================================
]]
--- @class MoneyPropertyDef
local MoneyPropertyDef = class(NumberPropertyDef)

-- Ctor is required
function MoneyPropertyDef:_init(params)
    self:super(params)
end

function MoneyPropertyDef:GetVType()
    return Constants.vtype.money
end

function MoneyPropertyDef:getNativeType()
    return 'integer'
end

---@param dbv DBValue
---@param v any
function MoneyPropertyDef:ImportDBValue(dbv, v)
    local vv = tonumber(v) * 10000
    local s = string.format('%.1f', vv)
    if s:byte(#s) ~= 48 then
        -- Last character must be '0' (ASCII 48)
        error(string.format('%s.%s: %s is not valid value for money',
                self.ClassDef.Name.text, self.Name.text, v))
    end
    dbv.Value = tonumber(s:sub(1, #s - 2))
end

-- TODO GetValueSchema - check  if value is number with up to 4 decimal places

--[[
===============================================================================
IntegerPropertyDef
===============================================================================
]]

--- @class IntegerPropertyDef
local IntegerPropertyDef = class(NumberPropertyDef)

function IntegerPropertyDef:_init(params)
    self:super(params)
end

--- @overload
--function IntegerPropertyDef:isValidDef()
--    local ok, errorMsg = NumberPropertyDef.isValidDef(self)
--    if not ok then
--        return ok, errorMsg
--    end
--
--    -- Check minValue and maxValue
--    local maxV = math.min(tonumber(self.D.rules.maxValue or Constants.MAX_INTEGER), Constants.MAX_INTEGER)
--    local minV = math.max(tonumber(self.D.rules.minValue or Constants.MIN_INTEGER), Constants.MIN_INTEGER)
--    if minV > maxV then
--        return false, 'Invalid minValue or maxValue settings'
--    end
--
--    return true
--end

function IntegerPropertyDef:getNativeType()
    return 'integer'
end

---@param op string @comment 'C' or 'U'
function IntegerPropertyDef:GetValueSchema(op)
    local result = self:buildValueSchema(schema.AllOf(schema.NumberFrom(self.D.rules.minValue or Constants.MIN_INTEGER,
            self.D.rules.maxValue or Constants.MAX_INTEGER), schema.Integer))
    return result
end

--[[
===============================================================================
TextPropertyDef
===============================================================================
]]

--- @class TextPropertyDef
local TextPropertyDef = class(PropertyDef)

function TextPropertyDef:_init(params)
    self:super(params)
end

--- @overload
--function TextPropertyDef:isValidDef()
--    local ok, errorMsg = PropertyDef.isValidDef(self)
--    if not ok then
--        return ok, errorMsg
--    end
--
--    local maxL = tonumber(self.D.rules.maxLength or 0)
--    if maxL < 0 then
--        return false, 'Invalid maxLength. Must be non negative number'
--    end
--
--    -- TODO check regex
--
--    return true
--end

function TextPropertyDef:getNativeType()
    return 'text'
end

function TextPropertyDef:ColumnMappingSupported()
    return (self.D.rules.maxLength or 255) <= 255
end

---@param op string @comment 'C' or 'U'
function TextPropertyDef:GetValueSchema(op)
    -- TODO Check regex and maxLength
    local result = self:buildValueSchema(schema.String)
    return result
end

function TextPropertyDef:GetSupportedIndexTypes()
    return Constants.INDEX_TYPES.MUL + Constants.INDEX_TYPES.FTS + Constants.INDEX_TYPES.STD + Constants.INDEX_TYPES.UNQ
end

--[[
===============================================================================
SymNamePropertyDef
===============================================================================
]]

--- @class SymNamePropertyDef
local SymNamePropertyDef = class(TextPropertyDef)

function SymNamePropertyDef:_init(params)
    self:super(params)
end

function SymNamePropertyDef:ColumnMappingSupported()
    return true
end

function SymNamePropertyDef:GetVType()
    return Constants.vtype.symbol
end

---@param op string @comment 'C' or 'U'
function SymNamePropertyDef:GetValueSchema(op)
    -- TODO Check if integer matches NamesID
    local result = self:buildValueSchema(schema.OneOf(schema.String, schema.Integer))
    return result
end

function SymNamePropertyDef:GetSupportedIndexTypes()
    return Constants.INDEX_TYPES.MUL + Constants.INDEX_TYPES.STD + Constants.INDEX_TYPES.UNQ + Constants.INDEX_TYPES.FTS_SEARCH
end

--[[
===============================================================================
ReferencePropertyDef: base class for all referencing properties: enum, nested etc.
===============================================================================
]]

--- @class ReferencePropertyDef
local ReferencePropertyDef = class(PropertyDef)

-- Returns internal JSON representation of property
function ReferencePropertyDef:internalToJSON()
    local result = PropertyDef.internalToJSON(self)

    result.refDef = tablex.deepcopy(self.refDef)

    return result
end

function ReferencePropertyDef:ColumnMappingSupported()
    return false
end

-- true if property value can be used as user defined ID (UID)
function ReferencePropertyDef:CanBeUsedAsUID()
    return false
end

-- Returns schema for property value as schema for nested/owned/mixin
-- Used for mixins, owned and nested objects for insert and update
function ReferencePropertyDef:getValueSchemaAsObject()
    local result = self:buildValueSchema()
    return result
end

-- Returns schema for property value as schema for query filter (to fetch list of referenced IDs)
-- Used for normal references (except mixins, nested and owned objects) for both insert and update.
function ReferencePropertyDef:getValueSchemaAsFilter()

end

---@param op string @comment 'C' or 'U'
function ReferencePropertyDef:GetValueSchema(op)
    local result = self:buildValueSchema(schema.OneOf(schema.String, schema.Integer))
    return result
end

-- Creates instance of DBProperty for DBObject
---@param object DBObject
function ReferencePropertyDef:CreateDBProperty(object)
    local result = dbprops.ReferencePropertyDef(object, self)
    return result
end

function ReferencePropertyDef:_init(params)
    self:super(params)
end

function ReferencePropertyDef:initMetadataRefs()
    PropertyDef.initMetadataRefs(self)

    if self.D and self.D.refDef then
        self.ClassDef.DBContext:InitMetadataRef(self.D.refDef, 'classRef', ClassNameRef)
    end

    self.ClassDef.DBContext:InitMetadataRef(self.D.refDef, 'reverseProperty', PropNameRef)

    if self.D and self.D.refDef and self.D.refDef.dynamic then
        self.ClassDef.DBContext:InitMetadataRef(self.D.refDef.dynamic, 'selectorProp', PropNameRef)

        if self.D.refDef.dynamic.rules then
            for _, v in pairs(self.D.refDef.dynamic.rules) do
                if v then
                    self.ClassDef.DBContext:InitMetadataRef(v, 'classRef', ClassNameRef)
                end
            end
        end
    end
end

--- @overload
function ReferencePropertyDef:hasUnresolvedReferences()
    local result = PropertyDef.hasUnresolvedReferences(self)
    if not result then
        return result
    end

    if self.D.refDef.classRef and not self.D.refDef.classRef:isResolved() then
        return false
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
    PropertyDef.applyDef(self)

    if self.D.refDef then
        if self.D.refDef.classRef then
            self.D.refDef.classRef:resolve(self.ClassDef)
        end

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

function ReferencePropertyDef:isReference()
    return true
end

-- Creates instance of DBProperty for DBObject
---@param object DBObject
function ReferencePropertyDef:CreateDBProperty(object)
    local result = dbprops.LinkDBProperty(object, self)
    return result
end

--[[
===============================================================================
EnumPropertyDef

Inherited from reference property and overrides ImportDBValue and
ExportDBValue
===============================================================================
]]

--- @class EnumPropertyDef
local EnumPropertyDef = class(ReferencePropertyDef)

function EnumPropertyDef:_init(params)
    self:super(params)
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

    -- Resolve names
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

    self.ClassDef.DBContext.EnumManager:ApplyEnumPropertyDef(self)
end

function EnumPropertyDef:internalToJSON()
    local result = PropertyDef.internalToJSON(self)

    result.refDef = tablex.deepcopy(self.enumDef)

    return result
end

function EnumPropertyDef:initMetadataRefs()
    PropertyDef.initMetadataRefs(self)

    if self.D.enumDef then
        self.ClassDef.DBContext:InitMetadataRef(self.D.enumDef, 'classRef', ClassNameRef)

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

function EnumPropertyDef:GetVType()
    return Constants.vtype.enum
end

function EnumPropertyDef:GetSupportedIndexTypes()
    return Constants.INDEX_TYPES.MUL + Constants.INDEX_TYPES.STD + Constants.INDEX_TYPES.UNQ
            + Constants.INDEX_TYPES.FTS_SEARCH
end

---@return boolean, function
function EnumPropertyDef:BeforeDBValueSave(dbv)

    ---@return bool
    local function validateEnumRef()
        -- TODO

    end

    local resolved = validateEnumRef()
    if resolved then
        return true, nil
    end

    return true, validateEnumRef
end

--[[ Applies enum value to the property
Postpones operation till all scalar data for all objects in the transaction are done.
This ensures that all inter-references are resolved properly
]]
---@param dbv DBValue
---@param v string | number | boolean
function EnumPropertyDef:ImportDBValue(dbv, v)
    return nil, function()
        -- re-apply value
    end
end

-- Retrieves $uid value from referenced object
---@param dbo DBObject
---@param dbv DBValue
function EnumPropertyDef:ExportDBValue(dbo, dbv)

end

function EnumPropertyDef:SetValue()

end

--[[
===============================================================================
BoolPropertyDef
===============================================================================
]]
--- @class BoolPropertyDef
local BoolPropertyDef = class(PropertyDef)

function BoolPropertyDef:_init(params)
    self:super(params)
end

function BoolPropertyDef:getNativeType()
    return 'integer'
end

-- true if property value can be used as user defined ID (UID)
function BoolPropertyDef:CanBeUsedAsUID()
    return false
end

function BoolPropertyDef:GetSupportedIndexTypes()
    return Constants.INDEX_TYPES.MUL
end

--[[
===============================================================================
BlobPropertyDef
===============================================================================
]]

--- @class BlobPropertyDef
local BlobPropertyDef = class(PropertyDef)

function BlobPropertyDef:_init(params)
    self:super(params)
end

function BlobPropertyDef:getNativeType()
    return 'blob'
end

function BlobPropertyDef:ColumnMappingSupported()
    return (self.D.rules.maxLength or Constants.MAX_BLOB_LENGTH) <= 255
end

-- true if property value can be used as user defined ID (UID)
function BlobPropertyDef:CanBeUsedAsUID()
    return false
end

---@param dbv DBValue
function BlobPropertyDef:GetRawValue(dbv)
    -- TODO base64.decode
    return dbv.Value
end

-- Sets dbv.Value from source data v, with possible conversion and/or validation
---@param dbv DBValue
---@param v any
function BlobPropertyDef:ImportDBValue(dbv, v)
    local vv = base64.decode(v)

    if vv == nil and v ~= nil then
        dbv.Value = v
    else
        dbv.Value = vv
    end
end

---@param dbo DBObject
---@param dbv DBValue
---@return any
function BlobPropertyDef:ExportDBValue(dbo, dbv)
    local result = base64.encode(dbv.Value)
    return result
end

-- Binds Value parameter to insert/update .ref-values
---@param stmt sqlite3_statement
---@param param_no number
---@param dbv DBValue
function BlobPropertyDef:BindValueParameter(stmt, param_no, dbv)
    stmt:bind_blob(param_no, dbv.Value)
end

--[[
===============================================================================
UuidPropertyDef
===============================================================================
]]

--- @class UuidPropertyDef
local UuidPropertyDef = class(BlobPropertyDef)

function UuidPropertyDef:_init(params)
    self:super(params)
end

function UuidPropertyDef:GetSupportedIndexTypes()
    return Constants.INDEX_TYPES.MUL + Constants.INDEX_TYPES.STD + Constants.INDEX_TYPES.UNQ
end

--[[
===============================================================================
DateTimePropertyDef
===============================================================================
]]

--- @class DateTimePropertyDef
local DateTimePropertyDef = class(NumberPropertyDef)

function DateTimePropertyDef:_init(params)
    self:super(params)
end

function DateTimePropertyDef:GetVType()
    return Constants.vtype.datetime
end

function DateTimePropertyDef:validateValue(obj, path)
    if path == nil then
        return nil
    end

    if obj == nil then
        return schema.Error('Null date value', path)
    end

    local v, err = self:toJulian(obj)
    if err then
        return schema.Error(err, path)
    else
        -- Check min/max
        local lower = self.D.rules.minValue or Constants.MIN_NUMBER
        local upper = self.D.rules.maxValue or Constants.MAX_NUMBER
        if v >= lower and v <= upper then
            return nil
        else
            return schema.Error(string.format("Invalid value: %s must be between %s and %s", path, lower, upper), path)
        end
    end
end

---@param op string @comment 'C' or 'U'
function DateTimePropertyDef:GetValueSchema(op)

    local function ValidateDateTime(obj, path)
        return self:validateValue(obj, path)
    end

    return self:buildValueSchema(ValidateDateTime)
end

-- Attempts to convert arbitrary value to number in Julian calendar (number of days starting from 0 AC)
---@param value any
---@param culture string | nil
---@return number, string @comment date/time in Julian (the same as SQLite) and error message (nil if OK)
function DateTimePropertyDef:toJulian(value)
    if type(value) == 'string' then
        return parseDateTimeToJulian(value)
    elseif type(value) == 'number' then
        return value, nil
    elseif type(value) == 'table' then
        local result = stringifyDateTimeInfo(value)
        return result, nil
    else
        return 0, 'Unsupported value type for date/time'
    end
end

function DateTimePropertyDef:applyDef()
    PropertyDef.applyDef(self)

    ---@param cntnr table
    ---@param attrName string
    local function convertDateTime(cntnr, attrName)
        if cntnr and cntnr[attrName] then
            local v, err = self:toJulian(cntnr[attrName])
            if err then
                -- TODO 'Default data is not in valid format'
                error(err)
            end
            cntnr[attrName] = v
        end
    end

    convertDateTime(self.D, 'defaultValue')
    convertDateTime(self.D.rules, 'minValue')
    convertDateTime(self.D.rules, 'maxValue')
end

---@param dbv DBValue
function DateTimePropertyDef:GetRawValue(dbv)
    return self:toJulian(dbv.Value)
end

---@param dbv DBValue
---@param v any
function DateTimePropertyDef:ImportDBValue(dbv, v)
    if type(v) == 'string' then
        dbv.Value = parseDateTimeToJulian(v)
    elseif type(v) == 'number' then
        dbv.Value = tonumber(v)
    else
        error(string.format('Invalid value type of date property %s.%s: %s (%s)',
                self.PropDef.ClassDef.Name.text, self.PropDef.Name.text, v, type(v)))
    end
end

--[[
===============================================================================
TimeSpanPropertyDef
===============================================================================
]]

--- @class TimeSpanPropertyDef
local TimeSpanPropertyDef = class(DateTimePropertyDef)

function TimeSpanPropertyDef:_init(params)
    self:super(params)
end

function TimeSpanPropertyDef:GetVType()
    return Constants.vtype.timespan
end

--[[
===============================================================================
ComputedPropertyDef
===============================================================================
]]

--- @class ComputedPropertyDef
local ComputedPropertyDef = class(PropertyDef)

function ComputedPropertyDef:_init(params)
    self:super(params)
end

function ComputedPropertyDef:ColumnMappingSupported()
    return false
end

-- true if property value can be used as user defined ID (UID)
function ComputedPropertyDef:CanBeUsedAsUID()
    return false
end

-- Class level list of available property types
-- map for property types
PropertyDef.PropertyTypes = {
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
    ['fkey'] = EnumPropertyDef,
    ['foreignkey'] = EnumPropertyDef,
    ['reference'] = ReferencePropertyDef,
    ['link'] = ReferencePropertyDef,
    ['ref'] = ReferencePropertyDef,
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
    ['any'] = AnyPropertyDef,
}

-- All specific property classes
PropertyDef.Classes = {
    BoolPropertyDef = BoolPropertyDef,
    IntegerPropertyDef = IntegerPropertyDef,
    NumberPropertyDef = NumberPropertyDef,
    BlobPropertyDef = BlobPropertyDef,
    MoneyPropertyDef = MoneyPropertyDef,
    UuidPropertyDef = UuidPropertyDef,
    EnumPropertyDef = EnumPropertyDef,
    ReferencePropertyDef = ReferencePropertyDef,
    TextPropertyDef = TextPropertyDef,
    ComputedPropertyDef = ComputedPropertyDef,
    SymNamePropertyDef = SymNamePropertyDef,
    DateTimePropertyDef = DateTimePropertyDef,
    TimeSpanPropertyDef = TimeSpanPropertyDef,
    AnyPropertyDef = AnyPropertyDef,
}

-- Schema validation rules for property JSON definition
local EnumDefSchemaDef = tablex.deepcopy(NameRef.SchemaDef)
EnumDefSchemaDef.items = schema.Optional(schema.Collection(schema.Record {
    id = schema.OneOf(schema.String, schema.Integer),
    text = name_ref.IdentifierSchema,
    icon = schema.Optional(schema.String),
    imageUrl = schema.Optional(schema.String),
}))
EnumDefSchemaDef.refProperty = schema.Optional(name_ref.IdentifierSchema)

local EnumRefDefSchemaDef = {
    classRef = schema.OneOf(schema.Nil, name_ref.IdentifierSchema, schema.Collection(name_ref.IdentifierSchema)),
    mixin = schema.Optional(schema.Boolean),
}

local RefDefSchemaDef = {
    classRef = schema.OneOf(schema.Nil, name_ref.IdentifierSchema, schema.Collection(name_ref.IdentifierSchema)),
    dynamic = schema.Optional(schema.Record {
        selectorProp = name_ref.IdentifierSchema,
        rules = schema.Collection(schema.Record {
            regex = schema.String,
            classRef = name_ref.IdentifierSchema
        })
    }),

    --[[
    Property name ID (in `classRef` class) used as reversed reference property for this one. Optional. If set,
    Flexilite will ensure that referenced class does have this property (by creating if needed).
    'reversed property' is treated as slave of master definition. It means the following:
    1) reversed object ID is stored in [Value] field (master's object ID in [ObjectID] field)
         2) when master property gets modified (switches to different class or reverse property) or deleted,
         reverse property definition also gets deleted
         ]]
    reverseProperty = schema.Optional(name_ref.IdentifierSchema),

    --[[
    Defines number of items fetched as a part of master object load. Applicable only > 0
    ]]
    autoFetchLimit = schema.Optional(schema.AllOf(schema.Integer, schema.PositiveNumber)),

    autoFetchDepth = schema.Optional(schema.AllOf(schema.Integer, schema.PositiveNumber)),

    --[[
    Optional relation rule when object gets deleted. If not specified, 'link' is assumed
    ]]
    rule = schema.OneOf(schema.Nil,

    --[[
    Referenced object(s) are details (dependents).
    They will be deleted when master is deleted. Equivalent of DELETE CASCADE
    ]]
            'master',

    --[[
    Loose association between 2 objects. When object gets deleted, references are deleted too.
    Equivalent of DELETE SET NULL
    ]]
            'link',

    --[[
    Similar to master but referenced objects are treated as part of master object
    ]]
            'nested',

    --[[
    Object cannot be deleted if there are references. Equivalent of DELETE RESTRICT
    ]]
            'dependent'
    ),

    mixin = schema.Optional(schema.Boolean)
}

PropertyDef.Schema = schema.AllOf(schema.Record {
    rules = schema.AllOf(
            schema.Record {
                type = schema.OneOf(unpack(tablex.keys(PropertyDef.PropertyTypes))),
                subType = schema.OneOf(schema.Nil, 'text', 'email', 'ip', 'password', 'ip6v', 'url', 'image', 'html'), -- TODO list to be extended
                minOccurrences = schema.Optional(schema.AllOf(schema.NonNegativeNumber, schema.Integer)),
                maxOccurrences = schema.Optional(schema.AllOf(schema.Integer, schema.PositiveNumber)),
                maxLength = schema.Optional(schema.AllOf(schema.Integer, schema.NumberFrom(-1, Constants.MAX_INTEGER))),
                -- TODO integer, float or date/time, depending on property type
                minValue = schema.Optional(schema.Number),
                maxValue = schema.Optional(schema.Number),
                regex = schema.Optional(schema.String),
            },
            schema.Test(function(rules)
                return (rules.maxOccurrences or 1) >= (rules.minOccurrences or 0)
            end, 'maxOccurrences must be greater or equal than minOccurrences')
    ,

            schema.Test(function(rules)
                -- TODO Check property type
                return (rules.maxValue or Constants.MAX_NUMBER) >= (rules.minValue or Constants.MIN_NUMBER)
            end, 'maxValue must be greater or equal than minValue')
    ),

    index = schema.OneOf(schema.Nil, 'index', 'unique', 'range', 'fulltext'),
    noTrackChanges = schema.Optional(schema.Boolean),

    enumDef = schema.Case('rules.type',
            { schema.OneOf('enum', 'fkey', 'foreignkey'),
              schema.Optional(schema.Record(EnumDefSchemaDef)) },
            { schema.Any, schema.Any }),

    refDef = schema.Case('rules.type',
            { schema.OneOf('link', 'ref', 'reference'), schema.Record(RefDefSchemaDef) },
            { schema.OneOf('enum', 'fkey', 'foreignkey'), schema.Optional(schema.Record(EnumRefDefSchemaDef)) },
            { schema.Any, schema.Any }),

    -- todo specific property value
    defaultValue = schema.Any,
    accessRules = schema.Optional(AccessControl.Schema),
}
,
        schema.Test(
                function(propDef)
                    -- Test enum definition
                    local t = string.lower(propDef.rules.type)
                    if t == 'enum' or t == 'fkey' or t == 'foreignkey' then
                        local def = propDef.enumDef and 1 or 0
                        def = def + (propDef.refDef and 2 or 0)
                        return def == 1 or def == 2
                    end
                    return true
                end, 'Enum property requires either enumDef or refDef (but not both)'
        )
)

return PropertyDef
