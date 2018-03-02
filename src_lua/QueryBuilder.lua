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
local metalua = require 'metalua.compiler'

---@class FilterDef
---@field ClassDef ClassDef
---@field Expression string
---@field ast table
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

    local compiler = metalua.new()
    if not string.match(expr, '^%s*return%s*')
    then
        expr = 'return ' .. expr
    end
    self.Expression = expr
    self.ast = compiler:src_to_ast(expr)

    local best_index = self:find_best_index()
end

function FilterDef:is_and_expr(expr)

end

function FilterDef:is_property_name(expr)

end

function FilterDef:is_valid_value(expr)

end

function FilterDef:is_prop_expression(expr)
    if expr.tag == 'Op' and (expr[1] == 'lt' or expr[1] == 'le' or expr[1] == 'eq') then
        if self:is_property_name(expr[2]) and self:is_valid_value(expr[1]) then
            return true
        end
        if self:is_property_name(expr[1]) and self:is_valid_value(expr[2]) then
            return true
        end
    end
    return false
end

function FilterDef:find_best_index()

    -- Skip external wrapper and 'Return' tag - they will be always there
    local x = self.ast[1][1]
    if self:is_and_expr(x) or self:is_prop_expression(x) then

    end

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



