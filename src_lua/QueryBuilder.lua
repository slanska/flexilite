---
--- Created by slanska.
--- DateTime: 2017-10-31 3:20 PM
---

--[[
Parses query JSON string
Builds SQL query
]]

local schema = require 'schema'
local class = require 'pl.class'

local QueryBuilder = class()

QueryBuilder.Schema = schema.Record {

}

return QueryBuilder



