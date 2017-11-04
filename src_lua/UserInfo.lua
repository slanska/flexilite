---
--- Created by slanska.
--- DateTime: 2017-11-01 11:37 PM
---

local UserInfo = {}

function UserInfo:new(o)
    o = o or {
        UserID = '',
        Roles = {},
        Culture = {}
    }

    setmetatable(o, self)
    self.__index = self
    return o
end

-- sqlite function handler
function UserInfo.flexi_UserInfo(...)
    -- TODO
    local action, userInfo = ...


end

return UserInfo