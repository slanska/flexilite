--[[
Created by slanska on 2019-09-06.
]]

local class = require 'pl.class'
local List = require 'pl.List'
local util = require 'pl.utils'
local DictCI = require('Util').DictCI
local tablex = require 'pl.tablex'

--[[
    API for accessing native SQLite tables and (updatable) views. Mostly used for CRUD operations on views for relational data
]]
---@class SqliteTable
---@field DBContext DBContext
---@field tableName string
local SqliteTable = class()

-- -@type function (DBContext, string, number): string[]
local _getPKeys

---@param DBContext DBContext
---@param tableName string
---@param columnCount number @comment expected number of columns in primary key. Used for updatable views as
---there is no real primary key defined
---@return table<string, string | number>
local function _getPKeysHandler(DBContext, tableName, columnCount)
    local result = {}
    local real_pkey = false
    -- pragma table_info
    local sql = ('pragma table_info [%s];'):format(tableName)
    for row in DBContext:loadRows(sql) do
        --[[
        cid (0 based), name, type, notnull, dflt_value, pk (1 based)
        ]]
        if real_pkey or row.pk > 0 then
            real_pkey = true
            result[row.pk] = row.name
        elseif row.cid < columnCount then
            result[row.cid + 1] = row.name
        else
            goto Exit
        end
    end

    :: Exit ::
    return result
end

local function _initMemoizeFuncs()
    _getPKeys = util.memoize(_getPKeysHandler)
end

_initMemoizeFuncs()

---@param DBContext DBContext
local function onFlushSchemaData()
    _initMemoizeFuncs()
end

---@param DBContext DBContext
---@param tableName string
function SqliteTable:_init(DBContext, tableName)
    self.DBContext = DBContext
    self.tableName = tableName

    self.DBContext.events:on(DBContext.EVENT_NAMES.FLUSH_SCHEMA_DATA, onFlushSchemaData)
end

---Converts where clause to dictionary, with keys as column names, and values as column values
---@param where any
function SqliteTable:_normalizeWhere(where)
    local cnt = #where
    if cnt > 0 then
        -- There are values for primary keys
        return self:getPrimaryKeys(cnt)
    end

    return where
end

---@param columnCount number @comment expected number of columns in primary key. Used for updatable views as
---there is no real primary key defined
---@return string[]
function SqliteTable:getPrimaryKeys(columnCount)
    local result = _getPKeys(self.DBContext, self.tableName, columnCount)
    return result
end

---@param self SqliteTable
---@param sql table @comment List
---@param where table
local function appendWhere(self, sql, where)
    sql:append ' where '
    local first = true
    for name, _ in pairs(where) do
        if first then
            first = false
        else
            sql:append ' and '
        end
        sql:append(('[%s] = :%s'):format(name, name))
    end
end

---@param data table
local function _generate_insert_sql(self, data)
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
    return sql
end

---@param data table
function SqliteTable:insert(data)
    local sql = _generate_insert_sql(self, data)
    self.DBContext:execStatement(sql, data)
end

---@param self DBContext
---@param data table
---@param where table @comment array of primary keys
local function _generate_update_sql(self, data, where)
    assert(where, 'where must be not null')
    local sql = List()
    sql:append(('update [%s] set'):format(self.tableName))
    local first = true
    for fieldName, fieldValue in pairs(data) do
        if not first then
            sql:append ', '
        else
            first = false
        end
        sql:append(('[%s] = :%s'):format(fieldName, fieldName))
    end

    local pkeys = self:_normalizeWhere(where)
    appendWhere(self, sql, pkeys)

    sql:append ';'

    return sql, pkeys
end

---@param data table
---@param where table @comment array of primary keys
function SqliteTable:update(data, where)
    local sql, pkeys = _generate_update_sql(self, data, where)
    local data = tablex.merge(data, pkeys)
    self.DBContext:execStatement(sql, data)
end

---@param where table  @comment array of primary keys
local function _generate_delete_sql(self, where)
    assert(where, 'where must be not null')

    local sql = List()
    sql:append(('delete from [%s] '):format(self.tableName))
    local data = self:_normalizeWhere(where)
    appendWhere(self, sql, data)

    sql:append ';'
    return sql, data
end

---@param where table  @comment array of primary keys
function SqliteTable:delete(where)
    local sql, data = _generate_delete_sql(self, where)
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
