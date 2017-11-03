---
--- Created by slanska.
--- DateTime: 2017-11-02 9:07 PM
---

local function Configure(DBContext, options)
    DBContext.db:exec(Flexi.DBSchemaSQL)
    if options then
        -- default culture
        -- default JSON output for flexi_data
        -- create virtual table
    end
end

return Configure