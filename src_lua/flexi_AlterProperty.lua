---
--- Created by slanska.
--- DateTime: 2017-11-02 9:01 PM
---

--[[
    /*
     Alters single class property definition.
     Supported cases:
     1) Convert property type: scalar to reference. Existing value is assumed as ID/Text of referenced object (equivalent of foreign key
     in standard RDBMS)
     2) Change property type, number of occurences, required/optional flag. Scans existing data, if found objects that do not pass
     rules, objects are marked as HAS_INVALID_DATA flag. LastActionReport will have 'warning' entry
     3) Change property indexing: indexed, unique, ID, full text index etc. For unique indexes existing values are verified
     for uniqueness. Duplicates are marked as invalid objects. Last action report will have info on this with status 'warning'
     4) Changes in reference definition: different class, reversePropertyID, selectorPropID. reversePropertyID will update existing links.
     Other changes do not have effect on existing data
     5) Converts reference type to scalar. Extracts ID/Text/ObjectID from referenced objects, sets value to existing links,
     */
]]

---
---
---@param self DBContext
---@param className string
---@param propertyName string
---@param newPropDefJsonString string
local function AlterProperty(self, className, propertyName, newPropDefJsonString)

end

return AlterProperty