---
--- Created by slanska.
--- DateTime: 2017-11-02 9:00 PM
---

local json = require 'cjson'
local ClassDef = require 'ClassDef'

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
    local newClass = ClassDef:fromJSON(self, destClassDef)

    -- Merge properties - one by one
    for i, p in ipairs(srcClass.Properties) do
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

    -- columnMapping
    newClass.columnMapping = newClass.columnMapping or srcClass.columnMapping or {}

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
---@param newClassDefJSON string @comment JSON encoded
---@param createVTable boolean
---@param invalidData string @comment (ignore - class will be marked as 'has invalid data',
-- fail throw error if invalid existing data are found (default))
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

    -- Check if property changes are ok

    -- If needed, scan data and validate against new definitions

    -- save changes
    -- replace class definition
    self:addClassToList(newClass)
end

return AlterClass, MergeClassDefinitions