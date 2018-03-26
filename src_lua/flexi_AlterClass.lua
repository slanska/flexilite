---
--- Created by slanska.
--- DateTime: 2017-11-02 9:00 PM
---

local json = require 'cjson'
local tablex = require 'pl.tablex'
local ClassDef = require 'ClassDef'

-- Detects differences between old and new properties.
-- Returns tuple of added, modified and unchanged properties.
-- Note that deleted properties are not processed by alter class, select flexi('drop property', ...) to be used for that
---@param oldProps table
---@param newProps table
---@return table, table, table @comment AddedProperties, ModifiedProperties, UnchangedProperties
local function getPropDifferences(oldProps, newProps)
    if not newProps then
        newProps = {}
    end

    -- order of params matters - properties from new list will replace old entries
    local existingProps = tablex.intersection(oldProps, newProps)
    local addedProps = tablex.difference(newProps, existingProps)
    local changedProps = tablex.filter(existingProps, function(pp, nn)
        local oldProp = oldProps[nn]
        return tablex.deepcompare(oldProp, pp)
    end)
    local unchangedProps = tablex.difference(oldProps, changedProps)

    return addedProps, changedProps, unchangedProps
end

--[[
Merges 2 class definitions - if given property is not defined in destClassDef, its counterpart from sourceClassDef is used
Properties are handled for each property individually, but entire individual property definition is used
(no merging on property level)
]]

---@param self DBContext
---@param srcClass ClassDef @see ClassDef
---@param destClassDef table @comment raw class definition decoded from JSON
---@return ClassDef @comment new class
local function MergeClassDefinitions(self, srcClass, destClassDef)
    local newClass = self.ClassDef:fromJSON(self, destClassDef)

    -- Merge properties - one by one
    for _, p in pairs(srcClass.Properties) do
        local propName = p.Name
        if not newClass.Properties[propName] then
            newClass:addProperty(p)
        end
    end

    -- Name
    newClass.Name = newClass.Name or srcClass.Name

    -- ID
    newClass.ID = newClass.ID or srcClass.ID

    -- specialProperties
    newClass.specialProperties = newClass.specialProperties or srcClass.specialProperties or {}

    -- rangeIndexing
    newClass.rangeIndexing = newClass.rangeIndexing or srcClass.rangeIndexing or {}

    -- fullTextIndexing
    newClass.fullTextIndexing = newClass.fullTextIndexing or srcClass.fullTextIndexing or {}

    -- allowAnyProps
    newClass.allowAnyProps = newClass.allowAnyProps or srcClass.allowAnyProps or false

    -- SystemClass
    newClass.SystemClass = newClass.SystemClass or srcClass.SystemClass or false

    -- VirtualTable
    newClass.VirtualTable = newClass.VirtualTable or srcClass.VirtualTable or false

    -- ctloMask
    newClass.ctloMask = newClass.ctloMask or srcClass.ctloMask or 0

    -- AccessRules
    newClass.AccessRules = newClass.AccessRules or srcClass.AccessRules or {}

    -- TODO Copy raw .classes fields

    return newClass
end

-- Alter class definition. Raises error if operation cannot be completed
---@param self DBContext
---@param className string
---@param newClassDefJSON string @comment JSON encoded (with properties by name)
---@param createVTable boolean @comment (optional) if nil, existing value will be used
---@param invalidData string @comment (optional) ('ignore' - class will be marked as 'has invalid data',
-- 'abort' (or any value other than 'ignore') throw error if invalid existing data are found (default))
local function AlterClass(self, className, newClassDefJSON, createVTable, invalidData)
    --assert(type(invalidData) == 'string' or invalidData == nil)

    local classDef = json.decode(newClassDefJSON)
    local newClassDef = self:newClassFromDef(classDef)
    local oldClassDef = self:getClassDef(className)

    if createVTable == nil then
        createVTable = oldClassDef.VirtualTable
    end

    if not invalidData then
        invalidData = 'abort'
    else
        invalidData = string.lower(invalidData)
    end

    -- load current definition
    -- verify that class already exists. If not - error

    -- merge definitions

    local addedProps, changedProps, unchangedProps = getPropDifferences()

    -- replace other class elements

    -- validate result
    --- properties


    --- specialProperties
    --- fullTextIndexing
    --- rangeIndexing

    -- Check if property changes are ok

    -- If needed, scan data and validate against new definitions

    -- Check if full text index definition has changed

    -- Check if multi key index definitions have changed

    -- Check if range index definition has changed
    if newClassDef.D.rangeIndexing and tablex.size(newClassDef.D.rangeIndexing) > 0 then
        -- Create range_data table
        newClassDef:createRangeDataTable()
    end

    -- save changes
    -- replace class definition
    self:addClassToList(newClassDef)

    ClassDef.ApplyIndexing(oldClassDef, newClassDef)

    self.SchemaChanged = true
end

return { AlterClass = AlterClass, MergeClassDefinitions = MergeClassDefinitions }