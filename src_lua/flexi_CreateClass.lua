---
--- Created by slanska.
--- DateTime: 2017-11-01 11:34 PM
---

local json = require 'cjson'

local alt_cls = require('flexi_AlterClass')
local AlterClass, MergeClassDefinitions = alt_cls.AlterClass, alt_cls.MergeClassDefinitions

-- Inserts row into .classes table, to get class ID
---@param self DBContext
---@param clsObject ClassDef
local function insertNewClass(self, clsObject)
    -- Save new class record to get ID
    clsObject.Name:resolve(clsObject)
    self:execStatement("insert into [.classes] (NameID) values (:ClassNameID);",
            {
                ClassNameID = clsObject.Name.id,
            })
    clsObject.D.ClassID = self.db:last_insert_rowid()
    clsObject.ClassID = clsObject.D.ClassID
end

--- Internal function to create class
---@param self DBContext
---@param className string
---@param classDef table @comment decoded JSON
---@param createVirtualTable boolean
--- Used to avoid multiple to/from JSON conversion
local function CreateClass(self, className, classDef, createVirtualTable)
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
        local sqlStr = string.format("create virtual table [%s] using flexi_data ('%q');", className, classDefAsJSON)
        self.db:exec(sqlStr)
        -- TODO Supply class ID
        return string.format('Virtual flexi_data table [%s] created', className)
    else
        local clsObject = self.ClassDef { newClassName = className, data = classDef, DBContext = self }

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

        insertNewClass(self, clsObject)

        -- TODO Set ctloMask
        clsObject.D.ctloMask = 0

        -- Apply definition
        for name, p in pairs(clsObject.Properties) do
            clsObject:assignColMappingForProperty(p)
            p:applyDef()
            local propID = p:saveToDB(nil, name)
            self.ClassProps[propID] = p
        end

        -- Check if class is fully resolved, i.e. does not have references to non-existing classes
        local unresolved = {}
        clsObject.D.Unresolved = false
        for _, p in pairs(clsObject.Properties) do
            if p:hasUnresolvedReferences() then
                clsObject.D.Unresolved = true
            end
        end

        clsObject.D.VirtualTable = false

        clsObject:saveToDB()
        self:addClassToList(clsObject)

        -- TODO Check if there unresolved classes

        return string.format('Class [%s] created with ID=[%d]', className, clsObject.ClassID)
    end
end

---@param self DBContext
---@param schema table
---@param createVirtualTable boolean
local function createMultiClasses(self, schema, createVirtualTable)
    for className, clsDef in pairs(schema) do
        CreateClass(self, className, clsDef, createVirtualTable)
    end
end

---@param self DBContext
---@param className string
---@param classDef table
---@param createVirtualTable boolean
local function createSingleClass(self, className, classDef, createVirtualTable)
    local schema = { [className] = classDef }
    createMultiClasses(self, schema, createVirtualTable)
end

--[[
Creates multiple classes

Classes are defined in JSON object, by name.
They are processed in few steps, to provide referential integrity:
1) After schema validation, all classes are saved in .classes table. Their IDs get established
2) Properties get updated ("applied"), with possible creation of reverse referencing and other properties and classes. No changes are saved yet.
2) All class properties get saved in .class_props table, to get IDs. No processing or validation happened yet.
3) Final steps - class Data gets updated with referenced class and property IDs and saved
]]
---@param self DBContext
---@param schemaJson string
---@param createVirtualTable boolean
local function CreateSchema(self, schemaJson, createVirtualTable)
    local schema = json.decode(schemaJson)
    createMultiClasses(self, schema, createVirtualTable)
end

return { CreateClass = CreateClass, CreateSchema = CreateSchema }