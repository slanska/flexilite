---
--- Created by slanska.
--- DateTime: 2017-12-26 11:56 AM
---

-- Validates class and property definition against schema

require 'util' -- to set paths
local path = require 'pl.path'
local schema = require 'schema'
local JSON = require 'cjson'
local ClassDef = require 'ClassDef'

--- Read file
---@param file string
local function readAll(file)
    local f = io.open(file, "rb")
    local content = f:read("*all")
    f:close()
    return content
end

-- load Northwind JSON schema
local northwindPath = path.abspath(path.relpath('../test/json/Northwind.db3.schema.json'))
local chinookPath = path.abspath(path.relpath('../test/json/Chinook.db.schema.json'))
local northwindData = JSON.decode(readAll(northwindPath))
local chinookData = JSON.decode(readAll(chinookPath))

-- load Chinook JSON schema
-- validate

describe('Class schema', function()

    it('should validate Northwind schema', function()
        local err = schema.CheckSchema(northwindData, ClassDef.MultiClassSchema)
        if err then
            print(err)
        end
    end)

    it('should validate Chinook schema', function()
        local err = schema.CheckSchema(chinookData, ClassDef.MultiClassSchema)
        if err then
            print(err)
        end
    end)

    it('should validate TextPropertyDef schema', function()

    end)

    it('should validate ReferencePropertyDef schema', function()

    end)

    it('should validate EnumPropertyDef schema', function()

    end)

    it('should validate ClassDef schema', function()

    end)

end)