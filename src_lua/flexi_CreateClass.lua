---
--- Created by slanska.
--- DateTime: 2017-11-01 11:34 PM
---

local JSON = require('cjson')
local AlterClass, MergeClassDefinitions = require('flexi_AlterClass')
local ClassDef = require 'ClassDef'

---
--- Creates a new class
--- if createVirtualTable == true, virtual table will be created
---@param self DBContext
---@param className string
---@param classDefAsJSONString string
---@param createVirtualTable boolean
---@return string
local function CreateClass(self, className, classDefAsJSONString, createVirtualTable)
    -- check if class with this name already exists
    local classID = self:getClassIdByName(className)
    if classID ~= 0 then
        error('Class ' .. className .. ' already exists')
    end

    -- validate name
    if not self:isNameValid(className) then
        error('Invalid class name' .. className)
    end

    -- load class definition
    local cls = ClassDef:fromJSONString(self, classDefAsJSONString)

    if type(createVirtualTable) == 'nil' then
        createVirtualTable = self.config.createVirtualTable
    end

    -- Validate props

    -- Check if all referenced classes are resolved. Otherwise, mark class as unresolved

    -- Apply for all properties

    if createVirtualTable then
        -- TODO Is this right way?

        -- Call virtual table creation
        local sql = {}
        table.insert(sql, 'create virtual table [' .. className .. '] using flexi_data (')

        -- TODO Schema, ClassName: create virtual table [%s] using flexi_data ()

        local first = true
        for i, p in ipairs(cls.Properties) do
            if not first then
                table.insert(sql, ',')
            else
                first = false
            end
            table.insert(sql, '[' .. p.Name .. '] ' .. p:getNativeType())
        end

        table.insert(sql, ');')

        local sqlStr = table:concat(sql, '\n')
        self.db:exec(sqlStr)
    else
        local classNameID
        local stmt = self:getStatement "insert into [.classes] (NameID, OriginalData) values (:1, :2);"
        stmt:reset()
        stmt:bind { [1] = classNameID, [2] = nil } -- TODO
        stmt:step()

        return 'Class [' .. className .. '] created'
    end

end

return CreateClass