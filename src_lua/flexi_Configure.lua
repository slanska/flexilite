---
--- Created by slanska.
--- DateTime: 2017-11-02 9:07 PM
---

local json = require('cjson')

---@param self DBContext
---@param sOptions string @comment
---@param sSchema string @comment list of classes
local function Configure(self, sOptions, sSchema)
    -- TODO check if flexi tables already exist

    local result = self.db:exec(Flexi.DBSchemaSQL)
    if result ~= 0 then
        local errMsg = string.format("%d: %s", self.db:error_code(), self.db:error_message())
        error(errMsg)
    end

    if sOptions then
        -- default culture
        -- default JSON output mode for flexi_data
        -- create virtual table
        -- supportedCultures
        -- defaultUser

        local options = json.decode(sOptions)
    end

    if sSchema then
        local schema = json.decode(sSchema)
    end
end

return Configure