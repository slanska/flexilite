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

        -- Save new class record to get ID
        clsObject.Name:resolve(clsObject)
        self:execStatement("insert into [.classes] (NameID) values (:1);",
        {
            ['1'] = clsObject.Name.id,
        })
        clsObject.D.ClassID = self.db:last_insert_rowid()
        clsObject.ClassID = clsObject.D.ClassID

        -- TODO Set ctloMask
        clsObject.D.ctloMask = 0

        -- Apply definition
        for name, p in pairs(clsObject.Properties) do
            clsObject:assignColMappingForProperty(p)
            p:applyDef()
            local propID = p:saveToDB(nil, name)
            clsObject.PropertiesByID[propID] = p
        end

        -- Check if class is fully resolved, i.e. does not have references to non-existing classes
        local unresolved = {}
        clsObject.D.Unresolved = false
        for id, p in ipairs(clsObject.Properties) do
            if p:hasUnresolvedReferences() then
                clsObject.D.Unresolved = true
                --table.insert(unresolved, string.format(""))
            end
        end

        local internalJson = json.encode(clsObject:internalToJSON())

        clsObject.D.VirtualTable = false

        self:execStatement("update [.classes] set NameID = :1, Data = :2, Unresolved = :3, ctloMask = :4 where ClassID = :5;",
        {
            ['1'] = clsObject.Name.id,
            ['2'] = internalJson,
            ['3'] = clsObject.D.Unresolved,
            ['4'] = clsObject.D.ctloMask,
            ['5'] = clsObject.ClassID
        })
        self:addClassToList(clsObject)

        -- TODO Check if there unresolved classes

        return string.format('Class [%s] created with ID=[%d]', className, clsObject.ClassID)
    end
end

--- Creates multiple classes
---@param self DBContext
---@param schemaJson string
---@param createVirtualTable boolean
local function CreateSchema(self, schemaJson, createVirtualTable)
    local schema = json.decode(schemaJson)
    for className, clsDef in pairs(schema) do
        print(string.format("Creating class [%s]", className))
        CreateClass(self, className, clsDef, createVirtualTable)
    end
end

return { CreateClass = CreateClass, CreateSchema = CreateSchema }