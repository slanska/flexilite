---
--- Created by slanska.
--- DateTime: 2017-11-02 9:01 PM
---

---@param self DBContext
---@param className string
---@param propName string @comment string for single property or array of strings for multiple properties
---@param vacuum boolean @comment (optional) if not false, existing property data will be purged. Otherwise, property
-- will be marked as 'Deleted' but data will stay
local function flexi_DropProperty(self, className, propName, vacuum)

end

return flexi_DropProperty