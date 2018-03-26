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

Flexilite will attempt to use the best index available. Logic is based on relative weights of every index
For example, if prop A and B are included into range index, and A is also indexed, then
filter A == 1 and B == 2 will use range index rather than index by A only.

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

---@class QueryBuilderIndexItem
---@field propID number
---@field cond string
---@field val nil | boolean | number | string | table @comment params.Name
---@field processed number

---@class FilterDef
---@field ClassDef ClassDef
---@field Expression string
---@field ast table
---@field indexedItems QueryBuilderIndexItem[] @comment property IDs may be duplicated
---@field params table
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
    self.ClassDef = ClassDef
    self.indexedItems = {}
    self.params = params

    if not string.match(expr, '^%s*return%s*')
    then
        expr = 'return ' .. expr
    end
    self.Expression = expr
    self.ast = lua_compiler:src_to_ast(expr)

    local best_index = self:build_index_query()
end

---@param astToken ASTToken
function FilterDef:process_token(astToken)
    if self:is_and_expr(astToken) then
    elseif self:is_prop_expression(astToken) then
    elseif self:is_match_call(astToken) then
        -- TODO
    end
end

-- Determines if astToken is MATCH function call
---@param astToken ASTToken
function FilterDef:is_match_call(astToken)
    astToken = skip_parens(astToken)
    if #astToken == 3 and astToken.tag == 'Call' then
        local callToken = astToken[1]
        if callToken and #callToken == 1 and callToken[1] == 'MATCH' and callToken.tag == 'Id' then
            -- first parameter is expected to be property name
            local prop = self:is_property_name(astToken[2])
            if not prop then
                return false
            end

            -- second parameter is expected to be string literal/param
            local propVal = self:is_valid_value(prop, astToken[3])
            if propVal then
                table.insert(self.indexedItems, { propID = prop.ID, cond = 'MATCH', val = propVal })
                return true
            end
        end
    end

    return false
end

---@param astToken ASTToken
function FilterDef:is_and_expr(astToken)
    astToken = skip_parens(astToken)
    if astToken.tag == 'Op' and astToken[1] == 'and' then
        self:process_token(astToken[2])
        self:process_token(astToken[3])
        return true
    end

    return false
end

-- Evaluates if astToken is property name
---@param astToken ASTToken | string[]
---@return PropertyDef | nil @comment property ID
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
    if astToken.tag == 'Number' or astToken.tag == 'String' then
        if not propDef then
            return nil
        end

        local dbv = DBValue { }
        local result = propDef:ImportDBValue(dbv, astToken[1])
        if type(result) == 'string' then
            result = escape_single_quotes(result)
        end
        return result
    end
    if astToken.tag == 'Index' and astToken[1].tag == 'Id' and astToken[1][1] == 'params'
            and astToken[2].tag == 'String' and type(astToken[2][1]) == 'string'
            and self.params then

        return string.format([['%s']], escape_single_quotes(astToken[2][1]))
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
    local cond = astToken.tag
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

---@param keyCount number @comment 2, 3, 4
---@return string | nil
function FilterDef:check_multi_key_index(keyCount)
    local indexes = self.ClassDef.indexes
    if not indexes then
        return nil
    end

    local mkey = indexes.multiKeyIndexing[keyCount]
    if mkey ~= nil then
        local result = List()
        for mkIndex, propID in ipairs(mkey) do
            for i, tok in ipairs(self.indexedItems) do
                if tok.propID == propID and tok.cond ~= 'MATCH' then
                    if #result > 0 then
                        result:append ' and '
                    end
                    result:append(string.format([[Z%d %s %s]], mkIndex, tok.cond, escape_single_quotes(tok.val)))
                    tok.processed = (tok.processed or 0) + 1

                    if tok.cond ~= '=' then
                        break
                    end
                end
            end
        end

        if #result > 0 then
            return string.format([[(select * from [.multi_key_%d] where %s)]], keyCount, result:join(''))
        end
    end

    return nil
end

function FilterDef:build_index_query()
    -- Skip external wrapper and 'Return' tag - they will be always there
    self:process_token(self.ast[1][1])

    ---@type List
    local result = List()
    result:append '('
    local indexes = self.ClassDef.indexes
    local firstCond = true

    -- multi key unique indexes
    ---@type string
    local mkey_filter = self:check_multi_key_index(4)
            or self:check_multi_key_index(3)
            or self:check_multi_key_index(2)

    -- check range indexing
    if indexes ~= nil and #indexes.rangeIndexing > 0 then
        local rngIdxMap = indexes:RangeIndexAsMap()
        for _, v in ipairs(self.indexedItems) do
            if v.cond ~= 'MATCH' then
                local i = rngIdxMap[v.propID]
                if i ~= nil then
                    if not firstCond then
                        result:append ' and '
                    else
                        firstCond = false
                    end
                    result:append(string.format([[%s %s %s]],
                                                indexes.rngCols[i], v.cond, escape_single_quotes(v.val)))
                    v.processed = (v.processed or 0) + 1
                end
            end
        end
    end

    -- 3) full text search
    if indexes ~= nil and #indexes.fullTextIndexing > 0 then
        local ftsCandidates = {}
        for i, v in ipairs(self.indexedItems) do
            if v.cond == 'MATCH' then
                table.insert(ftsCandidates, v.propID)
            end
        end
        ftsCandidates = tablex.intersection(ftsCandidates, indexes.fullTextIndexing)
        for i, propID in ipairs(ftsCandidates) do
            if #result == 0 then
                result:append(string.format([[select id from [.full_text_data] where ClassID=%d
                ]],
                                            self.ClassDef.ClassID))
            end
            result:append(string.format([[ and X%d match %s]], i, escape_single_quotes()))
        end
    end

    -- 4) single property indexes
    if indexes ~= nil then
        for i, v in ipairs(self.indexedItems) do
            if not v.processed and indexes.propIndexing[v.propID] then

            end
        end
    end

    return result:join('\n')
end

---@class QueryBuilder
local QueryBuilder = class()

function QueryBuilder:_init(DBContext)
    self.DBContext = DBContext
end

-- Returns list of object IDs, according to reference propDef and filter
---@param propDef PropertyDef
---@param filter FilterDef
function QueryBuilder:GetReferencedObjects(propDef, filter)

end

QueryBuilder.Schema = schema.Record {

}

return { QueryBuilder = QueryBuilder, FilterDef = FilterDef }