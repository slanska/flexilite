---
--- Created by slanska.
--- DateTime: 2017-11-01 11:34 PM
---

local AlterClass, MergeClassDefinitions = require('flexi_AlterClass')

--- @param self DBContext
local function ResolveClasses(self)
    -- TODO Find unresolved classes and try to resolve them
end

---
--- Creates a new class
--- if createVirtualTable == true, virtual table will be created
--- @param self DBContext
--- @param className string
--- @param classDefAsJSONString string
--- @param createVirtualTable boolean
--- @return string
local function CreateClass(self, className, classDefAsJSONString, createVirtualTable)
    -- check if class with this name already exists
    local classID = self:getClassIdByName(className, false)
    if classID ~= 0 then
        error('Class ' .. className .. ' already exists')
    end

    -- validate name
    if not self:isNameValid(className) then
        error('Invalid class name' .. className)
    end

    if createVirtualTable == 0 then
        createVirtualTable = false
    end

    if createVirtualTable == nil then
        createVirtualTable = self.config.createVirtualTable
    end

    if createVirtualTable then
        -- TODO Is this right way?

        -- Call virtual table creation
        local sqlStr = string.format("create virtual table [' .. className .. '] using flexi_data ('%q');", classDefAsJSONString)
        self.db:exec(sqlStr)
    else
        -- load class definition. Properties will be initialized and added to Properties
        local cls = self.ClassDef:fromJSONString(self, classDefAsJSONString)

        -- Validate class and its properties. Resolve if needed
        for name, prop in pairs(cls.Properties) do
            if not self:isNameValid(name) then
                error('Invalid property name: ' .. name)
            end

            local isValid, errorMsg = prop:isValidDef()
            if not isValid then
                error(errorMsg)
            end

            prop:resolve(self)
        end

        -- Apply definition
        for name, p in pairs(cls.Properties) do
            p:applyDef()
            local propID = p:saveToDB(nil, name)
            cls.Properties[propID] = p
        end

        -- Check if class is fully resolved, i.e. does not have references to non-existing classes
        cls.D.Unresolved = false
        for id, p in ipairs(cls.Properties) do
            if p:hasUnresolvedReferences() then
                cls.D.Unresolved = true
                break
            end
        end

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