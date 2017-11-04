---
--- Created by slanska.
--- DateTime: 2017-11-02 9:00 PM
---

local json = require 'cjson'

--[[
]]
local function AlterClass(DBContext, className, newClassDefJSON, createVTable)
    local classDef = json.decode(newClassDefJSON)
    createVTable = createVTable or false
end

--[[
]]
local function MergeClassDefinitions(DBContext, sourceClassDef, destClassDef)

end

return AlterClass, MergeClassDefinitions