--[[
Created by slanska on 2019-09-06.

This module implements helper class which provides API for insert/update/delete
operations on raw SQLite tables/updatable views. The main purpose of this class
is to have update operation support for Flexilite data update with regard to relational
views (auto-generated updatable views for many2many relations), though technically any
regular SQLite table or updatable should be supported as well.

All operations expect data in the same format (JSON) as normal Flexilite classes.
Also, update and delete operations expect where clause which could be either key-value table
(key is column name, value is column value) or array of column values. In the latter case
column value(s) must match primary key definitions. For many2many views this would be 2 columns,
for normal tables those should match primary key definition in accordance to result of SQLite's
pragma table_info.

For insert/update/delete operations class generates SQL, which is used to cache sqlite statements.
To avoid conflicts in names between value and where parameters the following naming convention is used:
Value parameters are named :v1, :v2 etc, where parameters are named: :k1, :k2 etc.
]]

local class = require 'pl.class'
local List = require 'pl.List'
local util = require 'pl.utils'
--local DictCI = require('Util').DictCI
local tablex = require 'pl.tablex'

--[[
    API for accessing native SQLite tables and (updatable) views. Mostly used for CRUD operations on views for relational data
]]
---@class SqliteTable
---@field DBContext DBContext
---@field tableName string
local SqliteTable = class()

---@class _SqliteTableMetadata
---@field col_by_names table<string, number> @comment map by lowercase column names and ordinal column index (as returned by pragma table_info)
---@field col_by_idx table<number, number> @comment map by primary key sequential number to ordinal column index

---@type (DBContext, string): _SqliteTableMetadata
local _get_table_meta_data

---@param DBContext DBContext
---@param tableName string
---@param expectedPKeyCount number @comment expected number of columns in primary key. Used for updatable views
---where is no real primary key defined
---@return _SqliteTableMetadata
local function _getTableMetadataHandler(DBContext, tableName)
    ---@type _SqliteTableMetadata
    local result = {
        col_by_names = {},
        col_by_idx = {},
    }
    -- pragma table_info
    local sql = ('pragma table_info [%s];'):format(tableName)
    for row in DBContext:loadRows(sql) do
        --[[
        cid (0 based), name, type, notnull, dflt_value, pk (1 based)
        ]]
        result.col_by_names[row.name:lower()] = row.cid
        if row.pk > 0 then
            result.col_by_idx[row.pk] = row.cid
        end
    end

    return result
end

local function _initMemoizeFuncs()
    _get_table_meta_data = util.memoize(_getTableMetadataHandler)
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
---@param metadata _SqliteTableMetadata
---@param where string | table<string, any>
function SqliteTable:_normalizeWhere(metadata, where)
    local result = {}
    for k, v in pairs(where) do
        local idx
        if type(k) == 'number' then
            -- use ordinal position = normally, this is updatable view
            idx = metadata.col_by_idx[k]
            for col_name, col_idx in pairs(metadata.col_by_names) do
                if col_idx == k then
                    result[col_name] = v
                    goto NEXT
                end
            end
        elseif type(k) == 'string' then
            local fieldName = k:lower()
            idx = metadata.col_by_names[fieldName]
            result[fieldName] = v
        end

        :: NEXT ::
    end
    return result
end

---@param sql table @comment List
---@param where table
local function _append_where(sql, where)
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
---@return string, table
function SqliteTable:_generate_insert_sql_and_params(data)
    local sql = List()
    local params = {}
    local first = true
    local valuesClause = List()
    ---@type _SqliteTableMetadata
    local metadata = _get_table_meta_data(self.DBContext, self.tableName, 0)
    sql:append(('insert into [%s] () values ('):format(self.tableName))
    for fieldName, fieldValue in pairs(data) do
        local cid = metadata.col_by_names[fieldName:lower()]
        if cid == nil then
            error(('Generate insert SQL. Column %s not found'):format(fieldName))
        end

        if not first then
            sql:append ', '
            valuesClause:append ', '
        else
            first = false
        end
        sql:append(('[%s]'):format(fieldName))
        local paramName = ('V%d'):format(cid)
        valuesClause:append(':' + paramName)
        params[paramName] = fieldValue
    end

    sql:append ') values ('
    sql:append(valuesClause)
    sql:append ');'
    return sql, params
end

---@param data table
function SqliteTable:insert(data)
    local sql, params = self:_generate_insert_sql_and_params(data)
    self.DBContext:execStatement(sql, params)
end

---@param self DBContext
---@param data table
---@param where table @comment array of primary keys
---@return string, table
function SqliteTable:_generate_update_sql_and_params(data, where)
    assert(where, 'where must be not null')
    ---@type _SqliteTableMetadata
    local metadata = _get_table_meta_data(self.DBContext, self.tableName, 0)

    local sql = List()
    local params = {}
    sql:append(('update [%s] set'):format(self.tableName))
    local first = true
    for fieldName, fieldValue in pairs(data) do
        local cid = metadata.col_by_names[fieldName:lower()]
        if cid == nil then
            error(('Generate update SQL. Column %s not found'):format(fieldName))
        end

        if not first then
            sql:append ', '
            first = false
        end
        local paramName = ('V%d'):format(cid)
        sql:append(('[%s] = :%s'):format(fieldName, paramName))
        params[paramName] = fieldValue
    end

    local pkeys = self:_normalizeWhere(metadata, where)
    _append_where(sql, pkeys)

    sql:append ';'

    return sql, pkeys
end

---@param data table
---@param where table @comment array of primary keys
function SqliteTable:update(data, where)
    local sql, pkeys = self:_generate_update_sql_and_params(data, where)
    local data = tablex.merge(data, pkeys)
    self.DBContext:execStatement(sql, data)
end

---@param where table  @comment array of primary keys
---@return string, table
function SqliteTable:_generate_delete_sql_and_params(where)
    assert(where, 'where must be not null')

    local metadata = _get_table_meta_data(self.DBContext, self.tableName)

    local sql = List()
    sql:append(('delete from [%s] '):format(self.tableName))
    local data = self:_normalizeWhere(metadata, where)
    _append_where(sql, data)

    sql:append ';'
    return sql, data
end

---@param where table  @comment array of primary keys
function SqliteTable:delete(where)
    local sql, data = self:_generate_delete_sql_and_params(self, where)
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
