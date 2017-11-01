---
--- Created by slan_ska.
--- DateTime: 2017-10-31 3:10 PM
---

--[[
Class definition
Has reference to DBContext
Collection of properties
Find property
Validates class structure
Loads class def from DB
Validates existing data with new class definition
]]

local PropertyDef = require('PropertyDef')
local NameRef = require('NameRef')

local ClassDef = {}

ClassDef.Properties = {}
ClassDef.new = function(DBContext)
    local self = { DBContext = DBContext }
    return self
end

return ClassDef

