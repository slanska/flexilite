---
--- Created by slanska.
--- DateTime: 2017-11-02 9:00 PM
---

local Constants = require 'Constants'
local AlterClass = require('flexi_AlterClass').AlterClass

---@param classDef ClassDef
---@param propName string
---@param propDef PropertyDef
---@return PropertyDef
local function createProperty(classDef, propName, propDef)
    local newClassDef = {
        properties = {
            [propName] = propDef
        }
    }

    return AlterClass(classDef.DBContext, classDef.Name.text, newClassDef)
end

-- Handler for flexi('create property', ...)
---@param self DBContext
---@param className string
---@param propName string
---@param propDef PropertyDef
local function flexi_CreateProperty(self, className, propName, propDef)
    local classDef = self:getClassDef(className)
    return createProperty(classDef, propName, propDef)
end

-- Internally used function to create auto property for classes
-- which allow arbitrary payload (allowAnyProps = true)
---@param self DBContext
---@param classDef ClassDef
---@param propName string
local function CreateAnyProperty(self, classDef, propName)
    local propDef = createProperty(classDef, propName, { rules = { type = 'any', minOccurrences = 0, maxOccurrences = Constants.MAX_INTEGER } })
    return propDef
end

return {
    CreateProperty = flexi_CreateProperty,
    CreateAnyProperty = CreateAnyProperty
}
