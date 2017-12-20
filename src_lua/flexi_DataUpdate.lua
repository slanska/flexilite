---
--- Created by slanska.
--- DateTime: 2017-11-01 11:27 PM
---

local json = require('cjson')

--[[
Implementation of flexi_data virtual table Update API: insert, update, delete
]]

---@param self DBContext
---@param className string
---@param data table
local function updateObject(self, className, data)
    -- find property IDs by names
    for name, value in pairs(data) do

    end

    -- validate properties
    -- call custom _before_ trigger (defined in Lua), first for mixin classes (if applicable)
    -- validate data, using dynamically defined schema. If any missing references found, remember them in Lua table
    -- save data, with multi-key, FTS and RTREE update, if applicable

    -- multi key - use pcall to catch error
    -- call custom _after_ trigger (defined in Lua), first for mixin classes (if applicable), then for *this* class

end

--[[
    CHECK_STMT_PREPARE(
            db,
            "insert into [.range_data] ([ObjectID], [ClassID_1], "
                    "[A0], [_1], [B0], [B1], [C0], [C1], [D0], [D1]) values "
                    "(:1, :2, :2, :3, :4, :5, :6, :7, :8, :9, :10);",
            &pCtx->pStmts[STMT_INS_RTREE]);

    CHECK_STMT_PREPARE(
            db,
            "update [.range_data] set "
                    "[A0] = :3, [A1] = :4, [B0] = :5, [B1] = :6, "
                    "[C0] = :7, [C1] = :8, [D0] = :9, [D1] = :10 where ObjectID = :1;",
            &pCtx->pStmts[STMT_UPD_RTREE]);

    CHECK_STMT_PREPARE(
            db, "delete from [.range_data] where ObjectID = :1;",
            &pCtx->pStmts[STMT_DEL_RTREE]);
]]

---
---@param self DBContext
---@param className string
--- (optional) if not specified, should be defined in JSON
---@param oldRowID number
--- if null, it is insert operation
---@param newRowID number
--- if null, it is delete. Otherwise, based on oldRowID, it is either insert or update
---@param dataJSON string
--- data payload. Can be single object or array of objects. If className is not set,
---payload should be object, with className as keys
---Examples: 1) single object, class is not null - {"Field1": "String", "Field2": 123...}
---2) array of objects, class is not null - [{"Field1": "String", "Field2": 123...}, {"Field1": "String2", "Field2": 123...}]
---2) class is null - {"Class1": [{"Field1": "String", "Field2": 123...}, {"Field1": "String2", "Field2": 123...}]...}
---@param queryJSON string
--- filter to apply - optional, for update and delete
local function flexi_DataUpdate(self, className, oldRowID, newRowID, dataJSON, queryJSON)
    local data = json.decode(dataJSON)

    if type(data) ~= 'table' then
        error('Invalid data type')
    end

    local query = json.decode(queryJSON)

    if #data > 0 then
        -- Array
        for i, v in ipairs(data) do
            updateObject(self, v)
        end
    else
        -- Object
        updateObject(self, data)
    end
end

return flexi_DataUpdate