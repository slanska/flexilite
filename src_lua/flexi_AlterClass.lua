---
--- Created by slanska.
--- DateTime: 2017-11-02 9:00 PM
---

local json = require 'cjson'

--[[
Merges 2 class definitions - if given property is not defined in destClassDef, its counterpart from sourceClassDef is used
Properties are handled for each property individually, but entire individual property definition is used
(no merging on property level)
]]

---@param self DBContext
---@param sourceClassDef ClassDef
---@param destClassDef table
-- (raw class definition decoded from JSON)
---@return ClassDef
-- (new class)
local function MergeClassDefinitions(self, sourceClassDef, destClassDef)
    local newClass = self:newClassFromDef(destClassDef)

    -- Properties - one by one
    newClass.Properties = newClass.Properties or sourceClassDef.Properties
    for i, p in ipairs(sourceClassDef.Properties) do
        local propName = p.Name
        if not newClass.Properties[propName] then
            newClass:addProperty(p)
        end
    end

    -- Name
    newClass.Name = newClass.Name or sourceClassDef.Name

    -- ID
    newClass.ID = newClass.ID or sourceClassDef.ID

    -- specialProperties
    newClass.specialProperties = newClass.specialProperties or sourceClassDef.specialProperties or {}

    -- rangeIndexing
    newClass.rangeIndexing = newClass.rangeIndexing or sourceClassDef.rangeIndexing or {}

    -- fullTextIndexing
    newClass.fullTextIndexing = newClass.fullTextIndexing or sourceClassDef.fullTextIndexing or {}

    -- allowAnyProps
    newClass.allowAnyProps = newClass.allowAnyProps or sourceClassDef.allowAnyProps or false

    -- columnMapping
    newClass.columnMapping = newClass.columnMapping or sourceClassDef.columnMapping or {}

    -- SystemClass
    newClass.SystemClass = newClass.SystemClass or sourceClassDef.SystemClass or false

    -- VirtualTable
    newClass.VirtualTable = newClass.VirtualTable or sourceClassDef.VirtualTable or false

    -- ctloMask
    newClass.ctloMask = newClass.ctloMask or sourceClassDef.ctloMask or 0

    -- AccessRules
    newClass.AccessRules = newClass.AccessRules or sourceClassDef.AccessRules or {}

    return newClass
end

-- Alter class definition. Raises error if operation cannot be completed
---@param self DBContext
---@param className string
---@param newClassDefJSON string
-- (JSON encoded)
---@param createVTable boolean
---@param invalidData string
-- (ignore - class will be marked as 'has invalid data', fail - throw error if invalid existing data are found (default))
local function AlterClass(self, className, newClassDefJSON, createVTable, invalidData)
    local classDef = json.decode(newClassDefJSON)
    createVTable = createVTable or false
    local cls = self:newClassFromDef(classDef)

    -- load current definition
    -- verify that class already exists. If not - error

    -- merge definitions

    -- validate result
    --- properties
    --- specialProperties
    --- fullTextIndexing
    --- rangeIndexing
    --- columnMapping: cannot change if locked

    -- Copy .classes fields

    -- Check if property changes are ok

    -- If needed, scan data and validate against new definitions

    -- save changes
    -- replace class definition
    self:addClassToList(newClass)
end

return AlterClass, MergeClassDefinitions