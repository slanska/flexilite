---
--- Created by slanska.
--- DateTime: 2017-11-01 11:34 PM
---

local JSON = require('cjson')
local AlterClass, MergeClassDefinitions = require('flexi_AlterClass')

---
--- Creates a new class
--- if createVirtualTable == true, virtual table will be created
---@param self DBContext
---@param className string
---@param classDefAsJSONString string
---@param createVirtualTable boolean
---@return string
local function CreateClass(self, className, classDefAsJSONString, createVirtualTable)
    local classDef = JSON.decode(classDefAsJSONString)

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
    local oldDef = self:LoadClassDefinition(classID)

    MergeClassDefinitions(self, classDef, oldDef)

    -- alter class definition

    local classNameID
    local stmt = self:getStatement "insert into [.classes] (NameID, OriginalData) values (:1, :2);"
    stmt:reset()
    stmt:bind { [1] = classNameID, [2] = nil } -- TODO
    stmt:step()

    return 'Class [' .. className .. '] created'
end

return CreateClass