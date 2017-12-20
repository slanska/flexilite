---
--- Created by slanska.
--- DateTime: 2017-12-19 7:13 AM
---

--[[
User exposed instance of [.object] record to be run in sandboxed mode.
Follows access rules, supports read-only mode etc.
Used to provide access to data from custom functions and triggers
]]

local class = require 'pl.class'

---@class ApiObject
local ApiObject = class()

---@param classDef IClassDef
---@param objectId number @comment optional, Int64
function ApiObject:_init(classDef, objectId)

end

return ApiObject