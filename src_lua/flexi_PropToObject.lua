---
--- Created by slanska.
--- DateTime: 2017-11-04 6:01 PM
---


--[[
    /*
     Extracts existing properties from class definition and creates a new property of OBJECT or REFERENCE type.
     New class will be created/or existing one will be updated.
     Key properties can be optionally passed to check if identical object of the target class already exists.
     In this case, new linked object will not be created, but reference will be set to existing one.
     Example: Country column as string. Then class 'Country' was created.
     Property 'Country' was extracted to the new class and replaced with link
     @filter:IObjectFilter,
     @propIDs:PropertyIDs,
     @newRefProp:IClassPropertyDef,
     @targetClassID:number,
     @sourceKeyPropID:PropertyIDs,
     @targetKeyPropID
     */
]]
---@param self DBContext
local function PropertyToObject(self)

end

return PropertyToObject