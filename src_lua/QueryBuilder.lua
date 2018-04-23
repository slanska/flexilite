---
--- Created by slanska.
--- DateTime: 2017-10-31 3:20 PM
---

--[[
Filter in Flexilite is defined in Lua expressions.
Data querying may be defined in 3 ways:
1) Lua string expression
2) table, which resembles MongoDB filter structure. This table gets converted to Lua string and processed as #1
3) standard SQL, via virtual tables

Flexilite tries to apply available indexes, if possible, to reduce of number of rows
to be processed.
At the end, all found rows are scanned and expression is applied in the context of current row

Index(es) are applied only when the following conditions are met:

- filter is only 'and' expression at the top level (Prop1 == 123 and Prop2 == 'abc').
'or', 'not' will fall back to full scan (e.g. Prop1 == 123 or Prop2 == 'abc')
- any branches with 'or', 'not' will lead to exclusion of entire branch from using index

Running query is done in the following steps:

1) parse filter to AST
2) analyzing which properties can be used for indexed search
3) building SQL, based on detected index(es)
4) running SQL and scanning all found rows
5) for every row found, filter expression gets executed in the FilterScope

Flexilite does not try to determine single best index. Instead, it builds sub-query which refers to
all applicable indexes and relies on SQLite to determine the actual best index.
Example (assuming P1 is indexed, and also included into range index, P2 has full text index):
P1 > 10 and MATCH(P2, 'Limpopo') => (select ObjectID from [.ref-values] where PropertyID = P1 and Value > 10
and <indexed>) q1 join (select ObjectID from .full_text_data where P2(X) matches 'Limpopo' and ClassID=<class_id>) q2
on q1.ObjectID = q2.ObjectID


In order to expression to qualify for index search the following criteria must be met:
- only sub-expressions like 'op constant' or match(propName, constant) (for full text search)
will be considered for indexing.
- expression may have only 'and'. 'or', 'not' will degrade to full scan

For multi-key indexes Flexilite will attempt to apply as much properties as possible.
For example, for multi-key index on A, B, C, D:
A == 1 and B > 2 -> multi-key index will be used on A and B
A == 1 and B == 2 and C < 10 -> multi-key index will be used on A, B and C
A == 1 and C == 10 -> multi-key index will be used on A only (because B is missing)
A > 1 and B == 2 -> multi-key index will be used on A only

]]

--[[
Parses query JSON string
Builds SQL query

Structure for filter is inspired by Mongo implementation
https://docs.mongodb.com/manual/reference/operator/query/

Examples:

1) propName = value
JSON:
{"propName": value}
Lua
{'propName' = value}

2) propName < value
JSON:
{"propName": {"$lt": value}}
Lua:
{'propName' = {['$lt'] = value}}

3) prop1 >= val1 AND prop2 in (1, 2, 3)
JSON:
[{"prop1": {"$ge": val1}}, {"prop2": {"$in": [1, 2, 3]}}]
Lua:
{{prop1 = {['$ge' = val1]}}, {prop2 = {['$in'] = {1, 2, 3}}}}

4) prop1 is null OR prop2 <> prop3
JSON:
{"$or": [{"prop1" : "$notnull"}, {"prop2": {"$ne": "prop3"}}]}
Lua:
{['$or'] = {{prop1 = '$notnull'}, {prop2 = {['$ne'] = 'prop3'}}}}


]]

--[[
'and' expression - index is used only both expressions fit into index definition
I.e. both idents are included into index

A0 > 1 and A1 < 10 and B0 > 2 and B1 < 20 and C0 == 30 -> range index will be used
]]

local schema = require 'schema'
local class = require 'pl.class'
local lua_compiler = require('metalua.compiler').new()
local tablex = require 'pl.tablex'
local List = require 'pl.list'
local DBValue = require 'DBValue'
local Constants = require 'Constants'
local pretty = require 'pl.pretty'
local bit52 = require('Util').bit52
local Sandbox = require 'sandbox'

---@class QueryBuilderIndexItem
---@field propID number
---@field cond string @comment >=, <, =, >, <=
---@field val nil | boolean | number | string | table @comment params.Name
---@field processed number @comment Counter of how many times property was included into index search

---@class FilterDef
---@field ClassDef ClassDef
---@field Expression string
---@field ast table
---@field indexedItems QueryBuilderIndexItem[] @comment property IDs may be duplicated
---@field params table
---@field matchCallCount number @comment Number of MATCH function calls
---@field callCount number @comment Total umber of function calls
local FilterDef = class()

---@class ASTToken
---@field tag string

---@param astToken ASTToken
---@return ASTToken
local function skip_parens(astToken)
    while astToken and astToken.tag == 'Paren' do
        astToken = astToken[1]
    end
    return astToken
end

local function escape_single_quotes(val)
    if type(val) == 'string' then
        return string.format([['%s']], string.gsub(val, [[']], [['']]))
    end
    return tostring(val)
end

---@class ExprItem
---@field isProp boolean
---@field weight number
---@field index string @comment 'range', 'fulltext', 'multikey'

---@param ClassDef ClassDef
---@param expr string
---@param params table
function FilterDef:_init(ClassDef, expr, params)
    self.ClassDef = assert(ClassDef)
    self.indexedItems = {}
    self.params = params

    if not string.match(expr, '^%s*return%s*')
    then
        expr = 'return ' .. expr
    end
    self.Expression = expr
    self.ast = lua_compiler:src_to_ast(expr)
end

---@param astToken ASTToken
function FilterDef:process_token(astToken)
    if self:is_and_or_not_expr(astToken) then
    elseif self:is_prop_expression(astToken) then
    elseif self:is_match_call(astToken) then
        -- TODO
    end
end

-- Clones ast and trims all non-expression tokens (i.e. function calls other than MATCH,
-- arithmetical operators etc)
---@param ast table
---@return table @comment trimmed clone of self.ast
function FilterDef:get_prop_expressions_only(ast)
    local result = tablex.map(function()

    end, ast)
    return result
end

-- Determines if astToken is MATCH function call
---@param astToken ASTToken
function FilterDef:is_match_call(astToken)
    astToken = skip_parens(astToken)
    if #astToken == 3 and astToken.tag == 'Call' then
        self.callCount = self.callCount + 1
        local callToken = astToken[1]
        if callToken and #callToken == 1 and callToken[1] == 'MATCH' and callToken.tag == 'Id' then
            -- first parameter is expected to be property name
            local prop = self:is_property_name(astToken[2])
            if not prop then
                return false
            end

            -- second parameter is expected to be string literal or param
            local propVal = self:is_valid_value(prop, astToken[3])
            if propVal then
                self.matchCallCount = self.matchCallCount + 1
                table.insert(self.indexedItems, { propID = prop.ID, cond = 'MATCH', val = propVal })
                return true
            end
        end
    end

    return false
end

---@param astToken ASTToken
---@param orCond string | nil @comment 'or'
---@param notCond string | nil @comment 'not'
function FilterDef:is_and_or_not_expr(astToken, orCond, notCond)
    astToken = skip_parens(astToken)
    if astToken.tag == 'Op' and (astToken[1] == 'and'
            or astToken[1] == orCond or astToken[1] == notCond) then
        self:process_token(astToken[2])
        self:process_token(astToken[3])
        return true
    end

    return false
end

-- Evaluates if astToken is property name
---@param astToken ASTToken | string[]
---@return PropertyDef | nil
function FilterDef:is_property_name(astToken)
    astToken = skip_parens(astToken)
    if astToken.tag == 'Id' and #astToken == 1 then
        local prop = self.ClassDef:hasProperty(astToken[1])
        return prop
    end
    return nil
end

-- Evaluates if astToken is literal value or param
---@param propDef PropertyDef
---@param astToken ASTToken | string[]
---@return number | string | nil
function FilterDef:is_valid_value(propDef, astToken)
    astToken = skip_parens(astToken)
    local vv
    if astToken.tag == 'Number' or astToken.tag == 'String' then
        if not propDef then
            return nil
        end
        vv = astToken[1]
    elseif astToken.tag == 'Index' and astToken[1].tag == 'Id' and astToken[1][1] == 'params'
            and astToken[2].tag == 'String' and type(astToken[2][1]) == 'string'
            and self.params then
        vv = self.params[astToken[2][1]]
    end

    if vv then
        local dbv = DBValue { }
        propDef:ImportDBValue(dbv, vv)
        local result = dbv.Value
        if type(result) == 'string' then
            result = escape_single_quotes(result)
        end
        return result
    else
        return nil
    end
end

local reversedConditions = {
    eq = '=',
    lt = '>',
    le = '>=',
}

local directConditions = {
    eq = '=',
    lt = '<',
    le = '<=',
}

---@param astToken ASTToken
function FilterDef:is_prop_expression(astToken)
    astToken = skip_parens(astToken)

    if astToken.tag == 'Op' and (astToken[1] == 'lt' or astToken[1] == 'le' or astToken[1] == 'eq') then
        local prop = self:is_property_name(astToken[2])
        local propVal = self:is_valid_value(prop, astToken[3])

        if prop and propVal then
            table.insert(self.indexedItems, { propID = prop.ID,
                                              cond = directConditions[astToken[1]], val = propVal })
            return true
        end
        prop = self:is_property_name(astToken[3])
        propVal = self:is_valid_value(prop, astToken[2])
        if prop and propVal then
            table.insert(self.indexedItems, { propID = prop.ID,
                                              cond = reversedConditions[astToken[1]], val = propVal })
            return true
        end
    end
    return false
end

-- Finds first matching index item, byt property ID. Starts from (optional) startIndex
-- If (optional) ignoreProcessed == true and item is marked as processed, item gets skipped
---@param propID number
---@param startIndex number | nil
---@param ignoreProcessed boolean | nil
---@return QueryBuilderIndexItem | nil, number
function FilterDef:find_indexed_prop(propID, startIndex, ignoreProcessed)
    local index = startIndex or 1
    while index <= #self.indexedItems do
        local pp = self.indexedItems[index]
        if pp.propID == propID and (not pp.processed or ignoreProcessed) then
            return pp, index
        end
    end

    return nil, index
end

-- Checks if there is multi-key index defined for this
---@param keyCount number @comment 2, 3, 4
---@param sql List
---@return string | nil
function FilterDef:check_multi_key_index(keyCount, sql)
    local indexes = self.ClassDef.indexes
    if not indexes then
        return nil
    end

    local mkey = indexes.multiKeyIndexing[keyCount]
    if mkey ~= nil then
        local itemsAdded = 0
        for mkIndex, propID in ipairs(mkey) do
            for i, tok in ipairs(self.indexedItems) do
                if tok.propID == propID and tok.cond ~= 'MATCH' then
                    sql:append ' and '
                    if itemsAdded == 0 then
                        sql:append(string.format([[(select * from [.multi_key_%d] where ]], keyCount))
                    end
                    itemsAdded = itemsAdded + 1
                    sql:append(string.format([[Z%d %s %s]], mkIndex, tok.cond, tok.val))
                    tok.processed = (tok.processed or 0) + 1
                end
            end
        end

        if itemsAdded > 0 then
            sql:append ')'
        end
    end

    return nil
end

---@param sql List
function FilterDef:process_range_index(sql)
    local indexes = self.ClassDef.indexes
    if indexes ~= nil and #indexes.rangeIndexing > 0 then
        local firstCond = true
        for _, v in ipairs(self.indexedItems) do
            if v.cond ~= 'MATCH' then
                local idx0 = tablex.find(indexes.rangeIndexing, v.propID)
                local idx1 = tablex.rfind(indexes.rangeIndexing, v.propID)
                local idx
                if v.cond == '>' or v.cond == '>=' or v.cond == '=' then
                    -- Use idx0
                    if idx0 then
                        idx = idx0
                    end
                else
                    -- Use idx1
                    if idx1 then
                        idx = idx1
                    end
                end

                if idx ~= nil then
                    if not firstCond then
                        sql:append ' and '
                    else
                        firstCond = false
                        sql:append(string.format('ObjectID in (select ObjectID from [.range_data_%d] where ',
                                                 self.ClassDef.ClassID))
                    end
                    sql:append(string.format([[(%s %s %s)]],
                                             indexes.rngCols[idx], v.cond, v.val))
                    v.processed = (v.processed or 0) + 1
                end
            end
        end

        if not firstCond then
            -- Some conditions were encountered - need to close sub-query statement
            sql:append(')')
        end
    end
end

---@param sql List
function FilterDef:process_full_text_index(sql)
    local indexes = self.ClassDef.indexes
    if indexes ~= nil and #indexes.fullTextIndexing > 0 then
        local ftsMap = indexes:IndexArrayToMap(indexes.fullTextIndexing)
        local firstFts = true
        for i, v in ipairs(self.indexedItems) do
            if v.cond == 'MATCH' then
                if ftsMap[v.propID] ~= nil then
                    if firstFts then
                        sql:append(string.format([[and ObjectID in (select id from [.full_text_data] where ClassID=%d
                ]],
                                                 self.ClassDef.ClassID))
                        firstFts = false
                    end
                    sql:append(string.format([[ and X%d match %s]], ftsMap[v.propID], v.val))
                end
            end
        end
        if not firstFts then
            sql:append(')')
        end
    end

end

-- Generates SQL for searching on individual properties
-- Takes into account: indexed, unique indexed, non indexed, mapped and non mapped properties
---@param sql List
function FilterDef:process_single_properties(sql)
    local indexes = self.ClassDef.indexes
    for i, v in ipairs(self.indexedItems) do
        local propDef = self.ClassDef.DBContext.ClassProps[v.propID]
        if propDef then
            local propIdx = self.ClassDef.indexes.propIndexing[propDef.ID]
            if propDef.ColMap ~= nil then
                -- Treat as .objects column
                sql:append(string.format('and (%s %s %s', propDef.ColMap, v.cond, v.val))
                if propIdx ~= nil then
                    -- Index
                    local colIdx = propDef:ColMapIndex()
                    local idxMask = propIdx == true
                            -- Unique index
                            and bit52.bnot(bit52.lshift(1, colIdx + Constants.CTLO_FLAGS.UNIQUE_SHIFT))
                            -- Non unique index
                            or bit52.bnot(bit52.lshift(1, colIdx + Constants.CTLO_FLAGS.INDEX_SHIFT))

                    sql:append(string.format(' and ctlo & %d <> 0)', idxMask))
                else
                    sql:append ')'
                end
            else
                -- Treat as .ref-values row
                sql:append(string.format([[ and ObjectID in (select ObjectID from [.ref-values]
                where PropertyID = %d and Value %s %s)]], propDef.ID, v.cond, v.val))
                if propIdx ~= nil then
                    sql:append(' and ctlv & %d <> 0',
                               propIdx == true and Constants.CTLV_FLAGS.UNIQUE or Constants.CTLV_FLAGS.INDEX)
                end
            end
        end
        if not v.processed then
            if indexes ~= nil then
                local idxMode = indexes.propIndexing[v.propID]
                if idxMode ~= nil and v.cond ~= 'MATCH' then
                    -- TODO
                    sql:append(string.format([[ and ObjectID in (select ObjectID from [.ref-values]
                        where PropertyID = %d and Value %s %s]], v.propID, v.cond, v.val))

                    local idxFlag = idxMode and Constants.CTLV_FLAGS.UNIQUE or Constants.CTLV_FLAGS.INDEX
                    sql:append(string.format(' and (ctlv & %d <> 0))', idxFlag))
                    v.processed = true
                end
            end

            -- Index was not found - apply direct search
            if not v.processed then
                if propDef and propDef.ColMap then
                    sql:append(string.format(' and (%s %s %s)', propDef.ColMap, v.cond, v.val))
                end
            end
        end
    end
end

---@param sql List
function FilterDef:process_multi_key_index(sql)
    local indexes = self.ClassDef.indexes
    ---@type string
    local mkey_filter = self:check_multi_key_index(4, sql)
            or self:check_multi_key_index(3, sql)
            or self:check_multi_key_index(2, sql)

    if mkey_filter ~= nil then
        -- TODO Generate mkey-based filter
        pretty.dump(mkey_filter)
    end
end

function FilterDef:build_index_query()
    self.matchCallCount = 0
    self.callCount = 0

    -- Skip external wrapper and 'Return' tag - they will be always there
    self:process_token(self.ast[1][1])

    ---@type List @comment used as a string builder
    local result = List()
    result:append(string.format('select * from [.objects] where ClassID = %d',
                                self.ClassDef.ClassID))

    -- 1) multi key unique indexes
    self:process_multi_key_index(result)

    -- 2) check range indexing
    self:process_range_index(result)

    -- 3) full text search
    self:process_full_text_index(result)

    -- 4) single property search - indexed or not
    self:process_single_properties(result)

    -- 5. For all 'indexable' tokens (i.e. those which meet criteria to search by index)
    -- and are column-mapped generate SQL 'where' clause to apply to .objects fields directly
    -- TODO

    print('-> SQL:' .. result:join(' ') .. '\n')
    --print('-> SQL:' .. result:join('\n'))

    return result:join('\n')
end

---@class QueryBuilder
---@field DBContext DBContext
local QueryBuilder = class()

-- Filter callback
function QueryBuilder:apply_filter()

end

---@param DBContext DBContext
function QueryBuilder:_init(DBContext, ClassDef, expr, params)
    expr = string.format('function () return %s end', expr)
    self.DBContext = DBContext
end

-- Returns list of object IDs, according to reference propDef and filter
---@param propDef PropertyDef
---@param filter FilterDef
function QueryBuilder:GetReferencedObjects(propDef, filter)

end

-- TODO
QueryBuilder.Schema = schema.Record {

}

--[[ Class which handles loading DBObjects by filter
Takes class definition, filter expression and parameters.
Uses FilterDef to build SQL. Executes SQL, iterates over all found [.objects],
uses sandbox for running compiled expression
applies expression to filter out objects. Stores found object IDs in ObjectIDs array property.
]]
---@class DBQuery
---@field ObjectIDs number[]
---@field _filterDef FilterDef
local DBQuery = class()

---@param ClassDef ClassDef
---@param expr string
---@param params table
function DBQuery:_init(ClassDef, expr, params)
    self._filterDef = FilterDef(ClassDef, expr, params)
    self.ObjectIDs = {}
end

---@return boolean @comment true if any objects were found
function DBQuery:Run()
    self.ObjectIDs = {}
    local sql = self._filterDef:build_index_query()
    --local rows =

    -- TODO set env.quote?

    local filterCallback, err = load(self._filterDef.Expression)
    if filterCallback == nil then
        -- TODO error (err)
    end

    -- objRow is [.objects]
    for objRow in self._filterDef.ClassDef.DBContext:LoadAdhocRows(sql, self._filterDef.params) do
        local dbobj = self._filterDef.ClassDef.DBContext:LoadObject(objRow.ObjectID, nil, false, objRow)
        assert(dbobj)
        local boxed = dbobj:GetSandBoxed(Constants.DBOBJECT_SANDBOX_MODE.FILTER)
        local sandbox_options = { env = boxed }
        local ok = Sandbox.run(filterCallback, sandbox_options)
        if ok then
            table.insert(self.ObjectIDs, objRow.ObjectID)
        end
    end

    return #self.ObjectIDs > 0
end

return { QueryBuilder = QueryBuilder, FilterDef = FilterDef, DBQuery = DBQuery }
