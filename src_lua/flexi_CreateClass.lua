---
--- Created by slanska.
--- DateTime: 2017-11-01 11:34 PM
---

local json = require 'cjson'

local alt_cls = require('flexi_AlterClass')
local AlterClass, MergeClassDefinitions = alt_cls.AlterClass, alt_cls.MergeClassDefinitions

--- Find unresolved classes and try to resolve them
--- @param self DBContext
local function ResolveClasses(self)
    -- TODO
end

--- Internal function to create class
---@param self DBContext
---@param className string
---@param classDefAsTable table @comment decoded JSON
---@param createVirtualTable boolean
---@param classDefAsJson string @comment optional. If passed, same as encoded classDefAsTable
--- Used to avoid multiple to/from JSON conversion
local function CreateClassFromJsonObject(self, className, classDefAsTable, createVirtualTable, classDefAsJson)
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
        if not classDefAsJson then
            classDefAsJson = json.encode(classDefAsTable)
        end

        local clsObject = self.ClassDef:fromJSON(self, classDefAsTable)
        -- load class definition. Properties will be initialized and added to Properties
        clsObject.Name.name = className

        -- Validate class and its properties
        for name, prop in pairs(clsObject.Properties) do
            if not self:isNameValid(name) then
                error('Invalid property name: ' .. name)
            end

            local isValid, errorMsg = prop:isValidDef()
            if not isValid then
                error(errorMsg)
            end
        end

        clsObject.PropertiesByID = {}
        -- Apply definition
        for name, p in pairs(clsObject.Properties) do
            p:applyDef()
            local propID = p:saveToDB(nil, name)
            clsObject.PropertiesByID[propID] = p
        end

        -- Check if class is fully resolved, i.e. does not have references to non-existing classes
        local unresolved = {}
        clsObject.Unresolved = false
        for id, p in ipairs(clsObject.Properties) do
            if p:hasUnresolvedReferences() then
                clsObject.Unresolved = true
                --table.insert(unresolved, string.format(""))
            end
        end

        clsObject.Name:resolve(clsObject)
        local classAsJson = json.encode(clsObject:internalToJSON())
        self:execStatement("insert into [.classes] (NameID, OriginalData, Data) values (:1, :2, :3);",
        {
            ['1'] = clsObject.Name.id,
            ['2'] = classDefAsJson,
            ['3'] = classAsJson })
        clsObject.ClassID = self.db:last_insert_rowid()
        self:addClassToList(clsObject)

        -- TODO Check if there unresolved classes

        return string.format('Class [%s] created with ID=[%d]', className, clsObject.ClassID)
    end
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
    local classDefAsTable = json.decode(classDefAsJSONString)
    return CreateClassFromJsonObject(    self, className, classDefAsTable,
    createVirtualTable, classDefAsJSONString)
end

--- Creates multiple classes
---@param self DBContext
---@param schemaJson string
---@param createVirtualTable boolean
local function CreateSchema(self, schemaJson, createVirtualTable)
    local schema = json.decode(schemaJson)
    for className, clsDef in pairs(schema) do
        print("Creating class [%s]", className)
        CreateClassFromJsonObject(self, className, clsDef, createVirtualTable, nil)
    end
end

return { CreateClass = CreateClass, CreateSchema = CreateSchema }