---
--- Created by slanska.
--- DateTime: 2017-11-23 10:32 PM
---

-- Default command line arguments if not passed

local SchemaNorthwind = {
    command = 'schema',
    database = '../data/Northwind.db3',
    output = '../test/json/Northwind.db3.schema.json',
}

local DumpNorthwind = {
    command = 'dump',
    database = '../data/Northwind.db3',
    output = '../test/json/Northwind.db3.data.json',
}

local DumpChinook = {
    command = 'dump',
    database = '../data/Chinook_Sqlite.db',
    output = '../test/json/Chinook.db.data.json',
}

local SchemaChinook = {
    command = 'schema',
    database = '../data/Chinook_Sqlite.db',
    output = '../test/json/Chinook.db.schema.json',
}

return SchemaChinook
