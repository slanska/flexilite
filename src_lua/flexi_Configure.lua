---
--- Created by slanska.
--- DateTime: 2017-11-02 9:07 PM
---

local json = cjson or require('cjson')

---@param self DBContext
---@param sOptions string | nil @comment
---@param sSchema string | nil @comment list of classes
local function Configure(self, sOptions, sSchema)
    -- Get SQL script to execute
    local sql_dbschema = require 'sql.dbschema'

    local result = self.db:exec(sql_dbschema)
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
        -- TODO process options
    end

    if sSchema then
        local schema = json.decode(sSchema)

        -- TODO Process new classes
    end

    return 'Flexilite schema has been configured'
end

return Configure
