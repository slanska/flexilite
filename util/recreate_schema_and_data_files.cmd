cd ./flexish
luajit ./index.lua schema "../data/Northwind.db3" -o "../test/json/Northwind.db3.schema.json" -cj false
luajit ./index.lua dump "../data/Northwind.db3" -o "../test/json/Northwind.db3.data.json" -cj false
luajit ./index.lua schema "../data/Chinook_Sqlite.db" -o "../test/json/Chinook.db.schema.json" -cj false
luajit ./index.lua dump "../data/Chinook_Sqlite.db" -o "../test/json/Chinook.db.data.json" -cj false
