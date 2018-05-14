---
--- Created by slanska.
--- DateTime: 2017-11-04 12:14 PM
---

--[[
Tests to implement:
- multi key index operations, index by 2, 3, 4 properties
- column mapping ops - CRUD
- unique and non-unique indexes
- search. Ensure that indexes are used
- range indexes: CRUD
- full text indexes: CRUD
- datetime and timespan properties. CRUD, indexing. Datetime parsing
- blob CRUD, ensure decoding/encoding from/to Base64
- ChangeLog updates
- data compare between original Northwind and Chinook databases and imported into Flexilite
]]

local util = require 'util'
local TestContext = util.TestContext()
TestContext.GetNorthwind()

-- Misc tests
require 'bit52'
require 'bad_class_schema'
require 'alter_prop'
require 'classSchema'
require 'create_class'
require 'misc'
require 'object_schema'
require 'prop_values'