---
--- Created by slanska.
--- DateTime: 2017-12-20 7:19 PM
---

--[[
Single value holder. Maps to row in [.ref-values] table.
Internally keeps 2 versions of fields: old_* (original values loaded from database)
and new_* (modified values).
Implements __index and __newindex metamethods to handle get and set
operations, so that setting, for example, self.PropIndex will
actually set self.new_PropIndex, and getting self.PropIndex will return
either new_PropIndex (if assigned earlier) or old_PropIndex.

For sake of memory utilization, assumes null PropIndex as 1 and null ctlv
as Property.ctlv. Normally, instance will have 3 fields set:
old_Property, old_Object, old_Value.
]]

local class = require 'pl.class'

---@class DBCell
local DBCell = class()

-- constructor
function DBCell:_init(row)
    assert(row.Property and row.Object)
    rawset(self, 'old_Property', row.Property)
    rawset(self, 'old_Object', row.Object)
    rawset(self, 'old_Value', row.Value)
    if row.PropIndex and row.PropIndex ~= 1 then
        rawset(self, 'old_PropIndex', row.PropIndex)
    end
    if row.ctlv and row.ctlv ~= row.Property.ctlv then
        rawset(self, 'old_ctlv', row.ctlv)
    end
    rawset(self, 'old_ExtData', row.ExtData)
end

function DBCell:__index(key)
    local result = rawget(self, 'new_' .. key )
    if result then
        return result
    end
    result = rawget(self, 'old_' .. key)
end

function DBCell:__newindex(key, value)
    rawset(self, 'new_' .. key, value)
end

function DBCell:isNew()

end

function DBCell:isDirty()

end

function DBCell:isDeleted()
    
end

function DBCell:beforeSaveToDB()
    -- Check if user can modify the property

    -- Check if there is column mapping
    if self.Property.ColMap then
        self.Object:setMappedPropertyValue(self.Property, value)
    end
end

function DBCell:afterSaveToDB()

end

function DBCell:saveToDB()

end

return DBCell