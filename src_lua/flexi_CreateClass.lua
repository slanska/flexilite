---
--- Created by slanska.
--- DateTime: 2017-11-01 11:34 PM
---

local JSON = require('cjson')
local AlterClass, MergeClassDefinitions = require('flexi_AlterClass')
local ClassDef = require 'ClassDef'

---@param self DBContext
local function ResolveClasses(self)

end


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

    if type(createVirtualTable) == 'nil' then
        createVirtualTable = self.config.createVirtualTable
    end

    -- Validate props

    -- Check if all referenced classes are resolved. Otherwise, mark class as unresolved

    -- Apply for all properties

    if createVirtualTable then
        -- TODO Is this right way?

        -- Call virtual table creation
        local sqlStr = string.format("create virtual table [' .. className .. '] using flexi_data ('%q');", classDefAsJSONString)
        self.db:exec(sqlStr)
    else
        -- load class definition
        local cls = ClassDef:fromJSONString(self, classDefAsJSONString)

        local classNameID
        local stmt = self:getStatement "insert into [.classes] (NameID, OriginalData) values (:1, :2);"
        stmt:reset()
        stmt:bind { [1] = classNameID, [2] = nil } -- TODO
        stmt:step()

        -- TODO Check if there unresolved classes

        return 'Class [' .. className .. '] created'
    end

end

return CreateClass