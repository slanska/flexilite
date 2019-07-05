---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by slanska.
--- DateTime: 2018-02-25 1:59 PM
---

--local util = require 'util'

--TODO local pretty = require 'pl.pretty'
local FilterDef = require('QueryBuilder').FilterDef

--local path = require 'pl.path'
--local CreateClass = require('flexi_CreateClass').CreateClass
--
-----@param DBContext DBContext
-----@return ClassDef
--local function createProductsClass(DBContext)
--    local __dirname = path.abspath('..')
--    local schemaFile = path.join(__dirname, 'test', 'json', 'Northwind.Products.schema.json')
--    local schema = util.readAll(schemaFile)
--
--    CreateClass(DBContext, 'Product', schema, false)
--    local classDef = DBContext:getClassDef('Product')
--    return classDef
--end
--
--local DBContext = util.openFlexiDatabaseInMem()
--local ProductClassDef = createProductsClass(DBContext)

local ProductClassDef = require 'test_class_def'

-- Tests for using indexes for query

---@class IndexCase
---@field expr string
---@field indexedProps QueryBuilderIndexItem[]
---@field params table | nil

---@type IndexCase[]
--[[
UnitsOnOrder
QuantityPerUnit
ReorderLevel
ProductID
UnitPrice
DiscontinuedDate
Discontinued
ProductName
UnitsInStock

Full text index:
ProductName
* Description

Range index:
UnitsOnOrder
QuantityPerUnit
ReorderLevel
UnitPrice

Non-unique index
DiscontinuedDate

Unique index
ProductName

Multi-key unique index

]]
local expr_cases = {
    { expr = [[ProductID == 6]], indexedProps = {
    } },
    { expr = [[ReorderLevel > 4 and ReorderLevel < 10]], indexedProps = {} },
    { expr = [[(QuantityPerUnit ~= 5)]], indexedProps = {
    } },
    { expr = [[((QuantityPerUnit == 7 and (ReorderLevel == 2 and UnitPrice > 3)))]], indexedProps = {
    } },
    { expr = [[MATCH(Description, 'Lucifer*')]], indexedProps = {
    } },
    { expr = [[MATCH(Description, 'Lucifer*') and MATCH(ProductName, params.ProductName)]], indexedProps = {
    },
      params = { ProductName = 'burn*' } },
    { expr = [[QuantityPerUnit > 8 and QuantityPerUnit < 10 and ReorderLevel >= 1.34
    and (ReorderLevel <= params.ReorderLevel and (UnitPrice >= '2015-11-07')) and DiscontinuedDate < params.DiscontinuedDate]],
      indexedProps = {

      },
      params = { ReorderLevel = 3.45, DiscontinuedDate = '2016-04-13T13:00' } },
    { expr = [[((QuantityPerUnit == 11 and (ReorderLevel == 12 or UnitPrice > 3)))]], indexedProps = {} },
    { expr = [[((QuantityPerUnit == 12 and (ReorderLevel == 12 and not UnitPrice > 3)))]], indexedProps = {} },
    { expr = [[((12 <= QuantityPerUnit and (12 >= ReorderLevel and 3 < UnitPrice)))]], indexedProps = {} },
    { expr = [[(11 < QuantityPerUnit and 12 > ReorderLevel and 13 <= UnitPrice and 14 >= QuantityPerUnit)]], indexedProps = {} },
    { expr = [[CategoryID == 6 and ProductName >= 'B' and ProductName < 'C']], indexedProps = {} },
}

---@param case IndexCase
local function generate_indexed_items(case)
    print('#Expression: '..case.expr)
    local filterDef = FilterDef(ProductClassDef, case.expr, case.params)
end

local function process_expr_cases()
    for _, case in ipairs(expr_cases) do
        generate_indexed_items(case)
    end
end

process_expr_cases()
