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
        local originalJSON
        if type(classDef) == 'string' then
            originalJSON = classDef
        else
            originalJSON = json.encode(classDef)
        end

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

        -- Apply definition
        for name, p in pairs(clsObject.Properties) do
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

        clsObject.Name:resolve(clsObject)
        local internalJson = json.encode(clsObject:internalToJSON())

        -- TODO ctloMask
        clsObject.D.ctloMask = 0

        clsObject.D.VirtualTable = false

        self:execStatement("insert into [.classes] (NameID, OriginalData, Data, Unresolved, ctloMask) values (:1, :2, :3, :4, :5);",
        {
            ['1'] = clsObject.Name.id,
            ['2'] = originalJSON,
            ['3'] = internalJson,
            ['4'] = clsObject.D.Unresolved,
            ['5'] = clsObject.D.ctloMask
        })
        clsObject.ClassID = self.db:last_insert_rowid()
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