---
--- Created by slanska
--- DateTime: 2017-11-06 11:03 PM
---

--[[
Enums in Flexilite is pretty much the same as references. When property is declared as enum,
new enum class will be automatically created (or existing enum class will
be used if classRef has valid enum class name defined).

Auto created enum class will have 2 special properties: uid (type will be based on type of id values in items list
- so it will be either integer or string), and name, type of 'symbol'

Optional item list will be used to populate data in the enum class. Existing items will be replaced, if their IDs match.

Enums are very similar to foreign key relation in standard RDBMS in sense that they store user defined ID,
not internal object ID, and do not support many-to-many relationship.

Any existing class can be used as enum class, if it has id and text special properties.
Also, auto created enum classes can be extended/modified like regular classes

Differences between enum and regular classes:
1) Enum property will be defined as computed property which returns $uid value for tha associated class
It may be scalar or array of values. During load, current $uid value will be retrieved based on
referenced object ID. So, JSON output will have values like "Status": "A"
or "Status": ["A", "B"], not like "Status": 123456
2) Internally enum will be stored and processed as a regular reference. All reference related
constraints (like cascade update or delete) will be applied too.
3) Enum property will be treated as a computed property with formula.get 'self[NNN]['$uid']', where NNN is ID of corresponding
implicit reference property. formula.set will change reference to another object on enum value change

Enum can be defined in enumDef or refDef. Only one of those is allowed, and supplying both will throw an error.
There are few differences in how enumDef and refDef are handled.
enumDef's purpose is for pure enum, i.e. enum value based on item list. refDef is for foreign keys.

For enumDef: classRef can be omitted, if not set, className_propertyName will be used to create a new enum class.
If class is not set, items are mandatory. If class set and already exists, items will be appended to existing
(if any) enum's items. If class set and does not yet exist, it will be created immediately.

For refDef: class is required. If it does not exist yet, its resolving will be deferred till the end of request processing
(so that multiple classes, referencing each other can be created). Note: class will NOT be created automatically,
it must exist or be created by user, as a normal class.
]]

local ClassCreate = require('flexi_CreateClass').CreateClass
local json = cjson or require 'cjson'
local NameRef = require 'NameRef'
local class = require 'pl.class'
local PropertyDef = require 'PropertyDef'

-- Implements enum storage
---@class RefDataManager
---@field DBContext DBContext
local RefDataManager = class()

---@param DBContext DBContext
function RefDataManager:_init(DBContext)
    ---@type DBContext
    self.DBContext = DBContext
end

---@param self RefDataManager
local function upsertEnumItem(self, propDef, item)
    ---@type ClassDef
    local classDef = self.DBContext:getClassDef(propDef.D.enumDef.id)
    local obj = self.DBContext:NewObject(classDef)
    local box = obj:Boxed()
    if classDef.D.specialProperties.uid.id then
        box[classDef.D.specialProperties.uid.text] = item.id
    end
    if classDef.D.specialProperties.text.id then
        box[classDef.D.specialProperties.text.text] = item.text
    end
    if classDef.D.specialProperties.icon.id then
        box[classDef.D.specialProperties.icon.text] = item.icon
    end
    if classDef.D.specialProperties.imageUrl.id then
        box[classDef.D.specialProperties.imageUrl.text] = item.imageUrl
    end

    obj:saveToDB()
end

-- Upserts enum item
---@param propDef EnumPropertyDef
---@param item table @comment with fields: id, text, icon, imageUrl
function RefDataManager:upsertEnumItem(propDef, item)
    -- Check if item can be added/updated now or must be deferred
    if propDef.D.enumDef.id then
        upsertEnumItem(self, propDef, item)
    else
        propDef.ClassDef.DBContext.DeferredActions:Add(nil, upsertEnumItem, self, propDef, item)
    end
end

--[[ Applies enum property definition
Ensures that corresponding
]]
---@param propDef EnumPropertyDef
function RefDataManager:ApplyEnumPropertyDef(propDef)
    assert(propDef:is_a(self.DBContext.PropertyDef.Classes.EnumPropertyDef))

    self.DBContext.ActionQueue:enqueue(function()
        if propDef.D.enumDef then
            -- Process as pure enum
            local refClsName
            if propDef.D.enumDef.classRef then
                refClsName = propDef.D.enumDef.classRef.text
            else
                refClsName = string.format('%s_%s', propDef.ClassDef.Name.text, propDef.Name.text)
            end

            -- TODO
            --if propDef.D.enumDef.items then
            --    self:UpsertEnumItems(refCls, propDef.D.enumDef.items)
            --end
        elseif propDef.D.refDef then
            -- Process as foreign key
            local refCls = self:ensureEnumClassExists(propDef.D.refDef.classRef.text)

            if refCls then
                -- TODO
            else
                -- TODO Defer resolving
                --self.DBContext:AddDeferredRef(propDef.D.refDef.classRef.text, propDef.D.refDef.classRef, 'id')
            end
        else
            error(string.format('%s.%s: either enumDef or refDef must be set',
                    propDef.ClassDef.Name.text, propDef.Name.text))
        end
    end)

end

-- Creates class for enum type, if needed.
---@param className string
---@param items table @comment (optional) array of EnumItem
---@return ClassDef
function RefDataManager:ensureEnumClassExists(className, items)
    local result = self.DBContext:getClassDef(className)
    if result then
        return result
    end

    -- Determine id type
    local idType = 'integer'
    if items and #items > 0 then
        for _, v in ipairs(items) do
            if type(v.id) ~= 'number' then
                idType = type(v.id)
                break
            end
        end
    end

    local def = {
        properties = {
            id = {
                rules = {
                    type = idType,
                    minOccurrences = 1,
                    maxOccurrences = 1,
                },
                index = 'unique'
            },
            name = {
                rules = {
                    type = 'symbol',
                    minOccurrences = 1,
                    maxOccurrences = 1,
                }
            },
        },

        specialProperties = {
            uid = { text = 'id' },
            name = { text = 'name' }
        }
    }

    -- Check if class already exists
    result = ClassCreate(self.DBContext, className, json.encode(def), false)

    -- Upsert items to enum class
    if items and #items > 0 then
        self:UpsertEnumItems(cls, items)
    end

    return result
end

---@param className string
function RefDataManager:IsClassEnum(className)
    local cls = self.DBContext:LoadClassDefinition(className)
    if not cls then
        return false, 'Class [' .. className .. '] does not exist'
    end

    local result = cls.D.specialProperties.id and cls.D.specialProperties.text

    return result
end

function RefDataManager:UpsertEnumItems(cls, items)
    if not items then
        return
    end

    -- use flexi_DataUpdate
    local stmt = self.DBContext:getStatement '' -- TODO SQL
    for _, v in ipairs(items) do
        local nameRef = { text = v.name }
        setmetatable(nameRef, NameRef)
        nameRef:resolve(cls)

        stmt:reset()
        stmt:bind { [1] = v.id, [2] = nameRef.id }
        stmt:exec()
    end
end

-- Imports reference value (in user defined ID format)
---@param self RefDataManager
---@param propDef ReferencePropertyDef
---@param classRef ClassNameRef
---@param dbv DBValue
---@param v any
local function _importReferenceValue(self, propDef, classRef, dbv, v)
    local className = classRef.text
    local refClassDef = self.DBContext:getClassDef(className, true)

    self.DBContext.ActionQueue:enqueue(function()
        local obj = refClassDef:getObjectByUdid(v, true)
        if obj then
            -- TODO insert/replace .ref-values entry
            return true
        end
        return false
    end)
end

-- Imports reference value (in user defined ID format)
---@param propDef ReferencePropertyDef
---@param dbv DBValue
---@param v any
---@return boolean, function @comment true, function if import was handled, false, nil, if not handled
function RefDataManager:importReferenceValue(propDef, dbv, v)

    if v == nil then
        PropertyDef.ImportDBValue(propDef, dbv, nil)
        return true, nil
    end

    --Pre-set user value
    PropertyDef.ImportDBValue(propDef, dbv, v)

    local processed = false
    -- First, try refDef
    local classRef = propDef.D.refDef and propDef.D.refDef.classRef or nil

    local function deferredImport()
        _importReferenceValue(self, propDef, classRef, dbv, v)
    end

    if classRef then
        _importReferenceValue(self, propDef, classRef, dbv, v)
        return true, deferredImport
    else
        -- Then, try enumDef
        classRef = propDef.D.enumDef and propDef.D.enumDef.classRef or nil
        if classRef then
            _importReferenceValue(self, propDef, classRef, dbv, v)
            PropertyDef.ImportDBValue(propDef, dbv, v)
            return true, deferredImport
        end
    end

    return false, nil
end

-- Imports reference value (in user defined ID format)
---@param propDef ReferencePropertyDef
---@param dbv DBValue
---@param v any
---@return function
function RefDataManager:importEnumValue(propDef, dbv, v)
    local processed, deferredAction = self:importReferenceValue(propDef, dbv, v)
    if processed then
        return deferredAction
    end

    local function deferredImport()
        -- TODO change to _importEnumValue (not yet implemented)
        _importReferenceValue(self, propDef, classRef, dbv, v)
    end

    -- TODO apply enum items
    PropertyDef.ImportDBValue(propDef, dbv, v)
    return true, deferredImport
end

return RefDataManager
