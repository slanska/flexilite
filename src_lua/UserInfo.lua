---
--- Created by slanska.
--- DateTime: 2017-11-01 11:37 PM
---

local UserInfo = {}

function UserInfo:new()
    local result = {
        UserID = '',
        Roles = {},
        Culture = {}
    }

    setmetatable(result, self)
    self.__index = self
    return result
end

-- sqlite function handler
function UserInfo.flexi_UserInfo(...)
    -- TODO
    local action, userInfo = ...


end

return UserInfo