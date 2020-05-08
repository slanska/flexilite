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

Flow for alter class/property:
* set new property metatable based on type
* initMetadataRefs - set metatable to metadata refs
* isValidDef - check if referenced properties exist etc
* canChangeTo - for alter operations
* if 'maybe' for at least one property - scan data, check isValidData
* applyDef (if alteration is OK)
* saveToDB
* ClassDef.rebuildIndexes - if new ctlv ~= old ctlv

For resolve class:
* load from db, set new property metatable based on type
* initMetadataRefs - set metatable to metadata refs
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
local generateRelView = require('flexi_rel_vtable').generateView
local bit52 = require('Util').bit52
local tonumber = _G.tonumber
local string = _G.string

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

---@class PropertyRefDef
---@field classRef ClassNameRef
---@field reverseProperty PropNameRef
---@field autoFetchLimit number
---@field autoFetchDepth number
---@field mixin boolean
---@field viewName string @comment optional name of view for many-to-many relationship
---@field viewColName string @comment optional name of corresponding column in many-to-many view
---@field reversedPropViewColName string @comment optional name of corresponding column in many-to-many view

---@class PropertyDefData
---@field rules PropertyRules
---@field enumDef PropertyEnumDef
---@field refDef PropertyRefDef
---@field accessRules table
---@field indexing string
---@field defaultValue any

---@class PropertyDefCtorParams
---@field ClassDef ClassDef
---@field newPropertyName string
---@field jsonData PropertyDefData
---@field dbrow table @comment [flexi_prop] structure

---@class PropertyDefCapabilities
---@field vtype string
---@field canBeUsedAsUDID boolean
---@field columnMappingSupported boolean
---@field supportsRangeIndexing boolean
---@field nativeType string
---@field supportedIndexTypes number

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
    local typeLowered = string.lower(params.jsonData.rules.type)
    local propCtor = PropertyDef.PropertyTypes[typeLowered]
    if not propCtor then
        error(('Unknown type %s of property [%s]'):format(typeLowered, params.newPropertyName))
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
        self.ctlvPlan = 0
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

---@return number @comment property ID
function PropertyDef:saveToDB()
    assert(self.ClassDef and self.ClassDef.DBContext)

    assert(self.Name and self.Name:isResolved(),
            string.format('Name of property %s is not resolved', self:debugDesc()))

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

function PropertyDef:getCtlvIndexMask()
    local idxType = string.lower(self.D.index or '')
    if idxType == 'index' then
        return Constants.CTLV_FLAGS.INDEX
    elseif idxType == 'unique' then
        return Constants.CTLV_FLAGS.UNIQUE
    else
        return 0
    end
end

--[[
Returns mask for search in partial SQLite index
Depending on col mapping mode returns it for ctlv or ctlo.
Used for building SQL queries which perform search on Flexilite indexes
]]
---@return number
function PropertyDef:getIndexMask()
    if self.ClassDef.ColMapActive and self.ColMap then
        local idxType = string.lower(self.D.index or '')
        local colIdx = self:ColMapIndex()
        if idxType == 'index' then
            return bit52.lshift(1, colIdx + Constants.CTLO_FLAGS.INDEX_SHIFT)
        elseif idxType == 'unique' then
            return bit52.lshift(1, colIdx + Constants.CTLO_FLAGS.UNIQUE_SHIFT)
        else
            return 0
        end
    end

    return self:getCtlvIndexMask()
end

-- Builds bit flag value for [.ref-value].ctlv field
---@return number
function PropertyDef:GetCTLV()
    local indexMask = self:getCtlvIndexMask()
    local result = bit.bor(self:GetVType(), indexMask)

    if self.D.noTrackChanges then
        result = bit.bor(result, Constants.CTLV_FLAGS.NO_TRACK_CHANGES)
    end

    return result
end

--Applies property definition to the database. Called on property save
function PropertyDef:beforeSaveToDB()
    self.ClassDef:assignColMappingForProperty(self)

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

-- Returns SQLite raw value type
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
---@return nil | function @comment If function is returned, it will be treated as pending action to be
---called at the second step of updates. Returning nil meand that dbv.Value was set successfully
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
---@param stmt userdata @comment sqlite3_statement
---@param param_no number
---@param dbv DBValue
function PropertyDef:BindValueParameter(stmt, param_no, dbv)
    stmt:bind(param_no, dbv.Value)
end

-- Returns index of column mapped
---@return number | nil
function PropertyDef:ColMapIndex()
    return self.ColMap ~= nil and string.lower(self.ColMap):byte() - string.byte('a') or nil
end

---@type PropertyDefCapabilities
local _propertyDefCapabilities = {
    nativeType = '',
    supportedIndexTypes = Constants.INDEX_TYPES.NON,
    canBeUsedAsUDID = true,
    columnMappingSupported = true,
    vtype = Constants.vtype.default,
    supportsRangeIndexing = false,
}

---@return PropertyDefCapabilities
function PropertyDef:getCapabilities()
    return _propertyDefCapabilities
end

---@param includeId boolean
---@return string
function PropertyDef:debugDesc(includeId)
    if includeId then
        return ('%s.%s[%s]'):format(self.ClassDef.Name.text, self.Name.text, self.ID)
    end
    return ('%s.%s'):format(self.ClassDef.Name.text, self.Name.text)
end

--[[
===============================================================================
AnyPropertyDef
===============================================================================
]]

---@class AnyPropertyDef @parent PropertyDef
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
--- @class NumberPropertyDef @parent PropertyDef
local NumberPropertyDef = class(PropertyDef)

function NumberPropertyDef:_init(params)
    self:super(params)
end

---@type PropertyDefCapabilities
local _numberPropertyDefCapabilities = tablex.deepcopy(_propertyDefCapabilities)
_numberPropertyDefCapabilities.nativeType = 'float'
_numberPropertyDefCapabilities.supportsRangeIndexing = true
_numberPropertyDefCapabilities.supportedIndexTypes = Constants.INDEX_TYPES.MUL + Constants.INDEX_TYPES.RNG + Constants.INDEX_TYPES.STD + Constants.INDEX_TYPES.UNQ

function NumberPropertyDef:getCapabilities()
    return _numberPropertyDefCapabilities
end

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
--- @class MoneyPropertyDef @parent NumberPropertyDef
local MoneyPropertyDef = class(NumberPropertyDef)

-- Ctor is required
function MoneyPropertyDef:_init(params)
    self:super(params)
end

local _moneyPropertyDefCapabilities = tablex.deepcopy(_numberPropertyDefCapabilities)
_moneyPropertyDefCapabilities.vtype = Constants.vtype.money
_moneyPropertyDefCapabilities.nativeType = 'integer'

function MoneyPropertyDef:getCapabilities()
    return _moneyPropertyDefCapabilities
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
    local s = ('%.1f'):format(vv)
    if s:byte(#s) ~= 48 then
        -- Last character must be '0' (ASCII 48)
        error(string.format('%s: %s is not valid value for money',
                self:debugDesc(), v))
    end
    dbv.Value = tonumber(s:sub(1, #s - 2))
end

-- TODO GetValueSchema - check  if value is number with up to 4 decimal places

--[[
===============================================================================
IntegerPropertyDef
===============================================================================
]]

--- @class IntegerPropertyDef @parent NumberPropertyDef
local IntegerPropertyDef = class(NumberPropertyDef)

function IntegerPropertyDef:_init(params)
    self:super(params)
end

local _integerPropertyDefCapabilities = tablex.deepcopy(_numberPropertyDefCapabilities)
_integerPropertyDefCapabilities.nativeType = 'integer'

function IntegerPropertyDef:getCapabilities()
    return _integerPropertyDefCapabilities
end

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

--- @class TextPropertyDef @parent PropertyDef
local TextPropertyDef = class(PropertyDef)

function TextPropertyDef:_init(params)
    self:super(params)
end

local _textPropertyDefCapabilities = tablex.deepcopy(_propertyDefCapabilities)
_textPropertyDefCapabilities.nativeType = 'text'
_textPropertyDefCapabilities.columnMappingSupported = true -- TODO
_textPropertyDefCapabilities.supportedIndexTypes = Constants.INDEX_TYPES.MUL + Constants.INDEX_TYPES.FTS + Constants.INDEX_TYPES.STD + Constants.INDEX_TYPES.UNQ

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

--- @class SymNamePropertyDef @parent TextPropertyDef
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

---@class ReferencePropertyDef : PropertyDef
---@field _viewGenerationPending boolean
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
        self.ClassDef.DBContext:InitMetadataRef(self.D.refDef, 'reverseProperty', PropNameRef)
    end
end

-- Private method to verify that relation view is created
function ReferencePropertyDef:_checkRegenerateRelView()

    ---@param refDef PropertyRefDef
    ---@return string
    local function _get_view_col_name(refDef)
        if refDef.viewColName then
            return refDef.viewColName
        end

        -- check id prop
        local idProp = self.ClassDef:getUdidProp()
        if idProp then
            return idProp.Name.text
        end

        -- assume self name - in most cases this would be incorrect though
        local result = self.Name.text
        return result
    end

    ---@param refDef PropertyRefDef
    ---@return string
    local function _get_reversed_view_col_name(refDef)
        if refDef.reversedPropViewColName then
            return refDef.reversedPropViewColName
        end

        -- check id column
        if refDef.classRef then
            local idProp = refDef.classRef:getUdidProp()
            if idProp then
                return idProp.Name.text
            end
        end

        -- assume self name - in most cases this would be incorrect though
        local result
        if refDef.reverseProperty then
            result = refDef.reverseProperty.text
        elseif refDef.classRef then
            result = refDef.classRef.text
        else
            error(string.format(
                    '%s: Reversed property or referenced class are required for relational view. Both refDef.classRef and refDef.reverseProperty',
                    self:debugDesc()))
        end
        return result
    end

    ---@type PropertyRefDef
    local refDef = self.D.refDef

    if refDef and refDef.viewName then
        -- Generate view for many-2-many relationship
        local thatName = _get_reversed_view_col_name(refDef)
        local thisName = _get_view_col_name(refDef)
        generateRelView(self.ClassDef.DBContext, refDef.viewName, self.ClassDef.Name.text,
                thisName, thisName, thatName)
    end

    self._viewGenerationPending = false
end

--- Override
---@return number @comment ID of saved property
function ReferencePropertyDef:saveToDB()
    local result = PropertyDef.saveToDB(self)

    if not self._viewGenerationPending then
        self._viewGenerationPending = true
        self.ClassDef.DBContext.ActionQueue:enqueue(function(self)
            self:_checkRegenerateRelView()
        end, self)
    end

    return result
end

-- TODO beforeApplyDef?
function ReferencePropertyDef:beforeSaveToDB()
    PropertyDef.beforeSaveToDB(self)

    ---@type PropertyRefDef
    local refDef = self.D.refDef
    if refDef then
        if refDef.classRef then
            refDef.classRef:resolve(self.ClassDef)
        end

        if refDef.reverseProperty then
            -- Check if reverse property exists. If no, create it
            ---@type ClassDef
            local revClassDef = self.ClassDef.DBContext:getClassDef(refDef.classRef.text, true)
            if not revClassDef:hasProperty(refDef.reverseProperty.text) then
                -- Create new ref property
                local propDef = {
                    rules = {
                        type = 'ref',
                        minOccurrences = 0,
                        maxOccurrences = Constants.MAX_INTEGER,
                    },
                    refDef = {
                        classRef = self.ClassDef.Name.text,
                        reverseProperty = self.Name.text,
                    }
                }
                local revPropDef = revClassDef:AddNewProperty(refDef.reverseProperty.text, propDef)
                revPropDef:beforeSaveToDB()

                --self.ClassDef.DBContext.ActionQueue:enqueue(function(params, dbContext)
                --    params.revPropDef:beforeSaveToDB()
                --    --local propID = params.revPropDef:saveToDB(nil, params.refDef.reverseProperty.text)
                --end, {
                --    revClassDef = revClassDef,
                --    revPropDef = revPropDef,
                --    refDef = refDef,
                --    self = self
                --})
            end

            --self.ClassDef.DBContext.ActionQueue:enqueue(function(params)
            refDef.reverseProperty:resolve(revClassDef)
            --end, { refDef = refDef, revClassDef = revClassDef})
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

---@param dbv DBValue
---@param v any
function ReferencePropertyDef:ImportDBValue(dbv, v)
    return self.ClassDef.DBContext.RefDataManager:importReferenceValue(self, dbv, v)
end

--[[
===============================================================================
EnumPropertyDef

Inherited from reference property and overrides ImportDBValue and
ExportDBValue
===============================================================================
]]

--- @class EnumPropertyDef : ReferencePropertyDef
local EnumPropertyDef = class(ReferencePropertyDef)

function EnumPropertyDef:_init(params)
    self:super(params)
end

function EnumPropertyDef:beforeSaveToDB()
    -- Note: calling PropertyDef, not ReferencePropertyDef
    PropertyDef.beforeSaveToDB(self)

    self.ClassDef.DBContext.ActionQueue:enqueue(function(self)
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

        self.ClassDef.DBContext.RefDataManager:ApplyEnumPropertyDef(self)
    end, self)
end

function EnumPropertyDef:internalToJSON()
    local result = ReferencePropertyDef.internalToJSON(self)

    result.refDef = tablex.deepcopy(self.enumDef)

    return result
end

function EnumPropertyDef:initMetadataRefs()
    ReferencePropertyDef.initMetadataRefs(self)

    if self.D.enumDef then
        self.ClassDef.DBContext:InitMetadataRef(self.D.enumDef, 'classRef', ClassNameRef)

        if self.D.enumDef.items then
            local newItems = {}
            for i, v in pairs(self.D.enumDef.items) do
                if v and v.text then
                    newItems[i] = NameRef(v.text, v.id)
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

--[[ Applies enum value to the property
Postpones operation till all scalar data for all objects in the transaction are done.
This ensures that all inter-references are resolved properly
]]
---@param dbv DBValue
---@param v string | number | boolean
function EnumPropertyDef:ImportDBValue(dbv, v)
    return self.ClassDef.DBContext.RefDataManager:importEnumValue(self, dbv, v)
end

-- Retrieves $uid value from referenced object
---@param dbo DBObject
---@param dbv DBValue
function EnumPropertyDef:ExportDBValue(dbo, dbv)
    -- TODO
end

--function EnumPropertyDef:SetValue()
--    -- TODO
--end
--
-- Checks if all dependency classes exist. May create a new one. Noop by default

-- TODO needed?
--function EnumPropertyDef:beforeApplyDef()
--    PropertyDef.beforeApplyDef(self)
--
--    if self.D.enumDef then
--        self.ClassDef.DBContext.RefDataManager:ApplyEnumPropertyDef(self)
--    end
--end

--[[
===============================================================================
BoolPropertyDef
===============================================================================
]]
--- @class BoolPropertyDef @parent PropertyDef
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

--- @class BlobPropertyDef @parent PropertyDef
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
---@param stmt userdata @comment sqlite3_statement
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

--- @class UuidPropertyDef @parent BlobPropertyDef
local UuidPropertyDef = class(BlobPropertyDef)

function UuidPropertyDef:_init(params)
    self:super(params)
end

function UuidPropertyDef:GetSupportedIndexTypes()
    return Constants.INDEX_TYPES.MUL + Constants.INDEX_TYPES.STD + Constants.INDEX_TYPES.UNQ
end

-- true if property value can be used as user defined ID (UID)
function UuidPropertyDef:CanBeUsedAsUID()
    return true
end

--[[
===============================================================================
DateTimePropertyDef
===============================================================================
]]

--- @class DateTimePropertyDef @parent NumberPropertyDef
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

function DateTimePropertyDef:beforeSaveToDB()
    PropertyDef.beforeSaveToDB(self)

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

--- @class TimeSpanPropertyDef @parent DateTimePropertyDef
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

--- @class ComputedPropertyDef @parent PropertyDef
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
    ['json'] = TextPropertyDef, -- TODO special prop class type???
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

local ClassRefSchema = schema.OneOf(schema.Nil, name_ref.IdentifierSchema, schema.Collection(name_ref.IdentifierSchema))

-- Schema validation rules for property JSON definition
local EnumDefSchemaDef = tablex.deepcopy(NameRef.SchemaDef)
EnumDefSchemaDef.items = schema.Optional(schema.Collection(schema.Record {
    id = schema.OneOf(schema.String, schema.Integer),
    text = schema.String,
    icon = schema.Optional(schema.String),
    imageUrl = schema.Optional(schema.String),
}))
EnumDefSchemaDef.refProperty = schema.Optional(name_ref.IdentifierSchema)

local EnumRefDefSchemaDef = {
    classRef = tablex.deepcopy(ClassRefSchema),
    mixin = schema.Optional(schema.Boolean),
}

local RefDefSchemaDef = {
    classRef = tablex.deepcopy(ClassRefSchema),

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
            'inner',

    --[[
    Object cannot be deleted if there are references. Equivalent of DELETE RESTRICT
    ]]
            'dependent'
    ),

    mixin = schema.Optional(schema.Boolean),

    viewName = schema.Optional(schema.String),
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
