---
--- Created by slanska.
--- DateTime: 2017-11-02 9:07 PM
---

---@param self DBContext
local function Configure(self, options)
    local result = self.db:exec(Flexi.DBSchemaSQL)
    if result ~= 0 then
        local errMsg = string.format("%d: %s", self.db:error_code(), self.db:error_message())
        error(errMsg)
    end

    if options then
        -- default culture
        -- default JSON output for flexi_data
        -- create virtual table
    end
end

return Configure