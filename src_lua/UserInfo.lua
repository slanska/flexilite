---
--- Created by slanska.
--- DateTime: 2017-11-01 11:37 PM
---

local class = require 'pl.class'

local UserInfo = class()

function UserInfo:_init(o)
    self.ID = ''
    self.Name = ''
    self.Roles = {}
    self.Culture = {}
end

-- sqlite function handler
function UserInfo.flexi_UserInfo(...)
    -- TODO
    local action, userInfo = ...


end

return UserInfo