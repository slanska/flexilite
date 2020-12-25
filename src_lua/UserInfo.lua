---
--- Created by slanska.
--- DateTime: 2017-11-01 11:37 PM
---

local class = require 'pl.class'
local schema = require 'schema'

---@class UserInfo
---@field ID string
---@field Name string
---@field Roles string[]
---@field Culture table
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

UserInfo.Schema = schema.Record {
    ID = schema.OneOf(schema.String, schema.Integer),
    Name = schema.Optional(schema.String),
    Roles = schema.OneOf(schema.Nil, schema.String, schema.Integer, schema.Collection(schema.OneOf(schema.String, schema.Integer))),
    Culture = schema.Optional(schema.String)
}

return UserInfo
