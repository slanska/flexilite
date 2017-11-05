---
--- Created by slanska.
--- DateTime: 2017-11-02 9:07 PM
---

---@param self DBContext
local function Configure(self, options)
    self.db:exec(Flexi.DBSchemaSQL)
    if options then
        -- default culture
        -- default JSON output for flexi_data
        -- create virtual table
    end
end

return Configure