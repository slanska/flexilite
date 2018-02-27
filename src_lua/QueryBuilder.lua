---
--- Created by slanska.
--- DateTime: 2017-10-31 3:20 PM
---

--[[
Filter in Flexilite is defined in Lua expressions.
Flexilite tries to apply available indexes, if possible, to reduce of number of rows
to be processed.
At the end, all found rows are scanned and expression is applied in the context of current row

In order to expression to qualify for index search the following criteria must be met:
- only sub-expressions like 'propName op constant' or match(propName, constant) (for full text search)
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
local lexer = require 'pl.lexer'

---@class FilterDef
---@field ClassDef ClassDef
---@field Expression string
local FilterDef = class()

local operators = {
    ['.'] = {},
    ['=='] = {},
    ['>'] = {},
    ['<'] = {},
    ['<='] = {},
    ['~='] = {},
    ['>'] = {},
    ['>='] = {},
    ['..'] = {},
    ['^'] = {},
    ['+'] = {},
    ['-'] = {},
    ['*'] = {},
    ['/'] = {},
    ['%'] = {},
    ['.'] = {},

}

-- Only these operators are considered for finding best index
local indexable_operators = {
    ['=='] = {},
    ['>'] = {},
    ['<'] = {},
    ['<='] = {},
    ['>'] = {},
    ['>='] = {},
}

---@class ExprItem
---@field isProp boolean
---@field weight number
---@field index string @comment 'range', 'fulltext', 'multikey'

---@param ClassDef ClassDef
---@param expr string
function FilterDef:_init(ClassDef, expr)
    self.ClassDef = ClassDef
    self.Expression = expr
    local best_index = self:find_best_index()
end

function FilterDef:find_best_index()
    --[[ Uses Penlight lexer to parse expr defined
    in a format resembling MongoDB filter expression in pseudo JSON.
    Generated execution flow in Polish (reversed notation), i.e. push val, push val,call op;
    op will push result to stack
    ]]
    local execFlow = {}
    local expectedToken = nil
    local curFlow = {}

    local op

    local symbol_stack = {}

    local function push_symbol(tok, val)

    end

    local function processToken(tok, val)
        local expected = 'prop'
        for tok, val in lexer.lua(self.Expression) do
            if tok == 'iden' then
                -- Treated as property name or class name
                -- after 'iden' we expect operator
                if expected == 'prop' and self.ClassDef:hasProperty(val) then
                    push_symbol(tok, val)
                else
                    return false
                end
            elseif tok == 'number' then
            elseif tok == 'keyword' then
                -- and, or, not
                if val == 'and' then

                else
                    return false
                end
            elseif tok == 'string' then
            elseif tok == '(' then
                if expected == 'prop' then

                end
                -- Inc paren
            elseif tok == ')' then
                -- Dec paren
            elseif indexable_operators[tok] ~= nil then
                table.insert(symbol_stack, tok)
            else
                return false
            end
        end
    end
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

--[[
"or", tag="Op"
"and", tag="Op"

]]

return QueryBuilder



