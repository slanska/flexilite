---
--- Created by slanska.
--- DateTime: 2017-11-02 9:00 PM
---

local Constants = require 'Constants'

-- Handler for flexi('create property', ...)
---@param self DBContext
---@param className string
---@param propName string
---@param propDef PropertyDef
local function flexi_CreateProperty(self, className, propName, propDef)

end

-- Internally used function to create auto property for classes
-- which allow arbitrary payload (allowAnyProps = true)
---@param self DBContext
---@param classDef ClassDef
---@param propName string
local function CreateAutoProperty(self, classDef, propName)
    local propDef = self.PropertyDef { rules = { type = 'any', minOccurrences = 0, maxOccurrences = Constants.MAX_INTEGER } }
end

return {
    CreateProperty = flexi_CreateProperty,
    CreateAutoProperty = CreateAutoProperty
}