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
Value parameters are named :v1, :v2 etc, and `where` parameters are named: :k1, :k2 etc.
]]

local class = require 'pl.class'
local List = require 'pl.List'
local util = require 'pl.utils'
local tablex = require 'pl.tablex'

--[[
    API for accessing native SQLite tables and (updatable) views. Mostly used for CRUD operations on views for relational data
]]
---@class SqliteTable
---@field DBContext DBContext
---@field tableName string
local SqliteTable = class()

---@class _SqliteTableMetadata
---@field col_by_idx table<number, string> @comment map by ordinal column index (as returned by pragma table_info) to column name
---@field col_by_names table<string, number> @comment map by lowercase column names and ordinal column index (as returned by pragma table_info)
---@field pkey_col_by_idx table<number, number> @comment map by primary key sequential number to ordinal column index

---@alias GetTableMetaDataHandler fun(DBContext: DBContext, tableName: string) : _SqliteTableMetadata
---@type GetTableMetaDataHandler
local _get_table_meta_data

local function _initMemoizeFuncs()
    _get_table_meta_data = util.memoize(
    ---@param DBContext DBContext

            function(DBContext)
                ---@param tableName string
                ---@return _SqliteTableMetadata
                return util.memoize(function(tableName)

                    ---@type _SqliteTableMetadata
                    local result = {
                        col_by_names = {},
                        col_by_idx = {},
                        pkey_col_by_idx = {}
                    }

                    -- pragma table_info
                    local sql = ('pragma table_info ([%s]);'):format(tableName)
                    for row in DBContext:loadRows(sql, {}) do
                        --[[
                        cid (0 based), name, type, notnull, dflt_value, pk (1 based)
                        ]]

                        local cname = row.name:lower()
                        local cid = row.cid + 1
                        result.col_by_names[cname] = cid
                        result.col_by_idx[cid] = cname
                        if row.pk > 0 then
                            result.pkey_col_by_idx[row.pk] = cid
                        end
                    end

                    return result
                end)
            end)
end

_initMemoizeFuncs()

---@param DBContext DBContext
local function onFlushSchemaData()
    _initMemoizeFuncs()
end

---@param DBContext DBContext
-----@param tableName string
function SqliteTable:_init(DBContext, tableName)
    assert(tableName and tableName ~= '')
    assert(DBContext)

    self.DBContext = DBContext
    self.tableName = tableName

    self.DBContext.events:on(DBContext.EVENT_NAMES.FLUSH_SCHEMA_DATA, onFlushSchemaData)
end

--[[ Converts where clause to dictionary, with keys as column names, and values as column values
`where` may come in 3 variants:
1) string - then is not processed and handled `as is`
2) array of values:
    2.1) if table has primary key definition, array item index is treated as ordinal position of primary key segment
    2.2) otherwise (table does not have primary key definition, and most likely it is an updatable view),
    array item index is treated as column ordinal position
3) dictionary of string keys:
]]
---@param sql table @comment List
---@param metadata _SqliteTableMetadata
---@param where string | table<string, any> | any[]
---@param params table
---@return table
function SqliteTable:_appendWhere(sql, metadata, where, params)

    if type(where) == 'string' then
        return where, params
    end

    local first = true
    for k, v in pairs(where) do
        local colName, paramName
        if type(k) == 'number' then
            -- use column ordinal position = normally, this is the case for updatable view
            local pkey_idx = metadata.pkey_col_by_idx[k]
            if pkey_idx ~= nil then
                -- there is a primary key, it is a regular table
                paramName = ('K%d'):format(pkey_idx)
                colName = metadata.col_by_idx[pkey_idx]
            else
                -- this is most likely an updatable view
                paramName = ('K%d'):format(k)
                colName = metadata.col_by_idx[k]
            end
        elseif type(k) == 'string' then
            -- key is a column
            colName = k:lower()
            local idx = metadata.col_by_names[colName]
            paramName = ('K%d'):format(idx)
        else
            error(('Invalid type of where parameter %s in %s'):format(k, self.tableName))
        end

        if first then
            sql:append ' where '
            first = false
        else
            sql:append ' and '
        end
        sql:append(('[%s] = %s'):format(colName, paramName))
        params[paramName] = v
    end
end

-- Returns generated SQL text and normalized parameters for `insert` statement
---@param data table
---@return string, table
function SqliteTable:_generate_insert_sql_and_params(data)
    local sql = List()
    local params = {}
    local first = true
    local valuesClause = List()
    ---@type _SqliteTableMetadata
    local metadata = _get_table_meta_data(self.DBContext)(self.tableName)

    sql:append(('insert into [%s] ('):format(self.tableName))
    for fieldName, fieldValue in pairs(data) do
        local cname = fieldName:lower()
        if type(cname) ~= 'string' then
            error(('Generate insert SQL. Column %s.%s not found'):format(self.tableName, fieldName))
        end

        local cid = metadata.col_by_names[cname]
        if cid == nil then
            error(('Generate insert SQL. Column %s.%s not found'):format(self.tableName, fieldName))
        end

        if not first then
            sql:append ', '
            valuesClause:append ', '
        else
            first = false
        end
        sql:append(('[%s]'):format(fieldName))
        local paramName = ('V%d'):format(cid)
        valuesClause:append(':' .. paramName)
        params[paramName] = fieldValue
    end

    sql:append ') values ('
    sql:append(valuesClause:join())
    sql:append ');'
    local sqlString = sql:join()
    return sqlString, params
end

---@param data table
function SqliteTable:insert(data)
    local sql, params = self:_generate_insert_sql_and_params(data)
    self.DBContext:execStatement(sql, params)
end

---@param self DBContext
---@param data table
---@param where table @comment array or dictionary of primary keys
---@return string, table
function SqliteTable:_generate_update_sql_and_params(data, where)
    assert(where, 'where must be not null')
    ---@type _SqliteTableMetadata
    local metadata = _get_table_meta_data(self.DBContext)(self.tableName)

    local sql = List()
    local params = {}
    sql:append(('update [%s] set'):format(self.tableName))
    local first = true
    for fieldName, fieldValue in pairs(data) do
        local cid = metadata.col_by_names[fieldName:lower()]
        if cid == nil then
            error(('Generate update SQL. Column %s.%s not found'):format(self.tableName, fieldName))
        end

        if first then
            first = false
        else
            sql:append ', '
        end

        local paramName = ('V%d'):format(cid)
        sql:append(('[%s] = :%s'):format(fieldName, paramName))
        params[paramName] = fieldValue
    end

    self:_appendWhere(sql, metadata, where, params)

    sql:append ';'
    local sqlString = sql:join()

    return sqlString, params
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

    local metadata = _get_table_meta_data(self.DBContext)(self.tableName)

    local sql = List()
    local params = {}
    sql:append(('delete from [%s] '):format(self.tableName))
    self:_appendWhere(sql, metadata, where, params)

    sql:append ';'
    local sqlString = sql:join()
    return sqlString, params
end

---@param where table  @comment array of primary keys
function SqliteTable:delete(where)
    local sql, data = self:_generate_delete_sql_and_params(self, where)
    self.DBContext:execStatement(sql, data)
end

---@return boolean
function SqliteTable:tableExists()
    -- TODO complete
    local sql = [[select * from sqlite_master where type in ('table', 'view')
    and name not like '.%' and name not like 'sqlite3_%' and name not like 'flexi_%']]
    self.DBContext:execStatement(sql)
    return true
end

return SqliteTable
