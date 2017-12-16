---
--- Created by slanska.
--- DateTime: 2017-11-23 10:32 PM
---

-- Default command line arguments if not passed
return
{
    command = 'schema',
    database = '../data/Chinook_Sqlite.db',
    output = '../test/json/Chinook.db.schema.json',
    --database = '../data/Northwind.db3',
    --output = '../test/json/Northwind.db3.schema.json',
}
