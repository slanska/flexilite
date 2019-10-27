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

function SqliteTable:getPrimaryKeys()

end

---@param self SqliteTable
---@param sql table @comment List
---@param where table
local function appendWhere(self, sql, where)
    sql:append ' where '
    -- TODO append where clause

end

---@param data table
function SqliteTable:insert(data)
    local sql = List()
    local first = true
    local valuesClause = List()
    sql:append(('insert into [%s] () values ('):format(self.tableName))
    for fieldName, fieldValue in pairs(data) do
        if not first then
            sql:append ', '
            valuesClause:append ', '
        else
            first = false
        end
        sql:append(('[%s]'):format(fieldName))
        valuesClause:append((':%s'):format(fieldName))
    end

    sql:append ') values ('
    sql:append(valuesClause)
    sql:append ');'
    self.DBContext:execStatement(sql, data)
end

---@param data table
---@param where table @comment array of primary keys
function SqliteTable:update(data, where)
    -- TODO

    assert(where, 'where must be not null')
    local sql = List()
    sql:append(('update [%s] set'):format(self.tableName))
    for fieldName, fieldValue in pairs(data) do
        if not first then
            sql:append ', '
        else
            first = false
        end
        sql:append(('[%s] = :%s'):format(fieldName, fieldName))
    end

    appendWhere(self, sql, where)

    sql:append ';'
    self.DBContext:execStatement(sql, data)
end

---@param where table  @comment array of primary keys
function SqliteTable:delete(where)
    -- TODO
    assert(where, 'where must be not null')

    local sql = List()
    sql:append(('delete from [%s] '):format(self.tableName))
    appendWhere(self, sql, where)

    sql:append ';'
    self.DBContext:execStatement(sql, data)
end

---@return boolean
function SqliteTable:tableExists()
    local sql = [[select * from sqlite_master where type in ('table', 'view')
    and name not like '.%' and name not like 'sqlite3_%' and name not like 'flexi_%']]
    self.DBContext:execStatement(sql)
    return true
end

return SqliteTable
