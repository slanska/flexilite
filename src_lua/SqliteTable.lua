--[[
Created by slanska on 2019-09-06.
]]

local class = require 'pl.class'
local List = require 'pl.List'

--[[
    API for accessing native SQLite tables and (updatable) views. Mostly used for CRUD operations on views for relational data
]]
---@class SqliteTable
---@field DBContext DBContext
---@field tableName string
local SqliteTable = class()

---@param DBContext DBContext
---@param tableName string
function SqliteTable:_init(DBContext, tableName)
    self.DBContext = DBContext
    self.tableName = tableName
end

---@param data table
function SqliteTable:insert(data)
    local sql = List()
    local first = true
    local values = List()
    sql:append(('insert into [%s] () values ('):format(self.tableName))
    for fieldName, _ in pairs(data) do
        if not first then
            sql:append ', '
            values:append ', '
        else
            first = false
        end
        sql:append(('[%s]'):format(fieldName))
        values:append((':%s'):format(fieldName))
    end


end

---@param data table
---@param where table
function SqliteTable:update(data, where)

end

---@param where table
function SqliteTable:delete(where)

end

---@return boolean
function SqliteTable:tableExists()
    local sql = [[select * from sqlite_master where type in ('table', 'view')
    and name not like '.%' and name not like 'sqlite3_%' and name not like 'flexi_%']]
    self.DBContext:execStatement(sql)
    return true
end

return SqliteTable
