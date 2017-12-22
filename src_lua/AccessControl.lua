---
--- Created by slanska.
--- DateTime: 2017-12-20 7:20 PM
---

--[[
Implements access control storage and permission verification
Used as a singleton object by DBContext
]]

local class = require 'pl.class'

---@class AccessControl
local AccessControl = class()

-- constructor
---@param DBContext DBContext
function AccessControl:_init(DBContext)
    self.DBContext = DBContext
end

function AccessControl:canUser(userCtx, accessRules, op)

end

return AccessControl