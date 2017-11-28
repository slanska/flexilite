---
--- Created by slanska.
--- DateTime: 2017-11-01 11:34 PM
---

local json = require 'cjson'

local AlterClass, MergeClassDefinitions = require('flexi_AlterClass')

--- @param self DBContext
local function ResolveClasses(self)
    -- TODO Find unresolved classes and try to resolve them
end

---
--- Creates a new class
--- if createVirtualTable == true, use 'CREATE VIRTUAL TABLE ... USING flexi_data ... '
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
        cls.Name.name = className

        -- Validate class and its properties
        for name, prop in pairs(cls.Properties) do
            if not self:isNameValid(name) then
                error('Invalid property name: ' .. name)
            end

            local isValid, errorMsg = prop:isValidDef()
            if not isValid then
                error(errorMsg)
            end
        end

        cls.PropertiesByID = {}
        -- Apply definition
        for name, p in pairs(cls.Properties) do
            p:applyDef()
            local propID = p:saveToDB(nil, name)
            cls.PropertiesByID[propID] = p
        end

        -- Check if class is fully resolved, i.e. does not have references to non-existing classes
        local unresolved = {}
        cls.Unresolved = false
        for id, p in ipairs(cls.Properties) do
            if p:hasUnresolvedReferences() then
                cls.Unresolved = true
                --table.insert(unresolved, string.format(""))
            end
        end

        cls.Name:resolve(cls)
        local classAsJson = json.encode(cls:internalToJSON())
        self:execStatement("insert into [.classes] (NameID, OriginalData) values (:1, :2);",
        { ['1'] = cls.Name.id, ['2'] = classAsJson })
        cls.ClassID = self.db:last_insert_rowid()

        -- TODO Check if there unresolved classes

        return string.format('Class [%s] created with ID=[%d]', className, cls.ClassID)
    end
end

--- Creates multiple classes
---@param self DBContext
---@param schemaJson string
---@param createVirtualTable boolean
local function CreateSchema(self, schemaJson, createVirtualTable)
    local schema = json.decode(schemaJson)
    for className, classDef in pairs(schema) do
        CreateClass(self, className, classDef, createVirtualTable)
    end
end

return { CreateClass = CreateClass, CreateSchema = CreateSchema }