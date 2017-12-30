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

---@class FilterDef
local FilterDef = class()

function FilterDef:_init()

end

---@class QueryBuilder
local QueryBuilder = class()

function QueryBuilder:_init(DBContext)
    self.DBContext = DBContext
end

-- Returns list of object IDs, according to reference propDef and filter
---@param propDef PropertyDef
---@param filter FilterDef
function QueryBuilder:GetReferencedObjects(propDef, filter)

end

QueryBuilder.Schema = schema.Record {

}

return QueryBuilder



