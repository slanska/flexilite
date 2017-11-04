---
--- Created by slanska.
--- DateTime: 2017-11-01 11:27 PM
---

local json = require('cjson')

--[[
Implementation of flexi_data virtual table Update API: insert, update, delete
]]

local function updateObject(DBContext)

end

---
---@param DBContext DBContext
---@param className string
---@param oldRowID number
---@param newRowID number
---@param dataJSON string
---@param queryJSON string
local function flexi_DataUpdate
(DBContext, className, oldRowID, newRowID, dataJSON, queryJSON)
    local data = json.decode(dataJSON)

    if type(data) ~= 'table' then
        error('Invalid data type')
    end

    local query = json.decode(queryJSON)

    if #data > 0 then
        -- Array
        for i, v in ipairs(data) do
            updateObject(DBContext, v)
        end
    else
        -- Object
        updateObject(DBContext, data)
    end

end

return flexi_DataUpdate