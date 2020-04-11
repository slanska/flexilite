---
--- Created by slanska.
--- DateTime: 2017-11-01 11:34 PM
---

--[[
select flexi('create class', class_name [, class_def_JSON]) or
select flexi('class create', class_name [, class_def_JSON]) or
select flexi('create', class_name [, class_def_JSON]) or
select flexi('class', class_name [, class_def_JSON])

Expected parameters:
class_name - required
class_def_JSON - optional. If not set, class with ad-hoc properties and no predefined
properties will be created
]]

local json = cjson or require 'cjson'
local schema = require 'schema'
local tablex = require 'pl.tablex'
local ClassDef = require 'ClassDef'
local List = require 'pl.List'
local table_insert = table.insert
local string = _G.string

local alt_cls = require('flexi_AlterClass')
local AlterClass, MergeClassDefinitions = alt_cls.AlterClass, alt_cls.MergeClassDefinitions

-- Inserts row into .classes table, to get class ID
---@param self DBContext
---@param classDef ClassDef
local function insertNewClass(self, classDef)
    -- Save new class record to get ID
    classDef.Name:resolve(classDef)
    self:execStatement("insert into [.classes] (NameID) values (:ClassNameID);",
            {
                ClassNameID = classDef.Name.id,
            })
    classDef.D.ClassID = self.db:last_insert_rowid()
    classDef.ClassID = classDef.D.ClassID
end

--- Creates multiple classes from schema definition
---@param self DBContext
---@param schemaDef table
---@param createVirtualTable boolean
local function createMultiClasses(self, schemaDef, createVirtualTable)

    -- Check schema for class definitions
    local err = schema.CheckSchema(schemaDef, self.ClassDef.MultiClassSchema)
    if err then
        local s = schema.FormatOutput(err)
        error(s)
    end

    --[[
    Classes' processing is done in few steps (or phases)
    1) Classes are added to NAMClasses, so that they become available for lookup by class name
    2) Properties are iterated and beforeApplyDef method gets fired, if applicable
    3) Class records are saved in .classes table so that classes get their persistent IDs
    4) Properties are saved in database (applyDef). They get persistent IDs. At this point
    5) Classes get their indexes applied and class definitions are saved (JSON portion only)
    6) apply new-and-modified classes
    ]]

    -- Utility function to iterate over all classes and their properties
    ---@param callback function @comment (className: string, ClassDef, propName: string, PropDef)
    local function forEachNAMClassProp(callback)
        if self.NAMClasses ~= nil then

            for className, classDef in pairs(self.NAMClasses) do
                if type(className) == 'string' and classDef.Properties ~= nil then
                    for propName, propDef in pairs(classDef.Properties) do
                        callback(className, classDef, propName, propDef)
                    end
                end
            end
        end
    end

    ---@param className string
    ---@param classDef ClassDef
    ---@param propName string
    ---@param propDef PropertyDef
    local function virtualTableOrNAM(className, classDef, propName, propDef)
        -- TODO
    end

    ---@param className string
    ---@param classDef ClassDef
    ---@param propName string
    ---@param propDef PropertyDef
    local function applyProp(_, classDef, propName, propDef)
        classDef:assignColMappingForProperty(propDef)
        propDef:applyDef()
    end

    ---@param className string
    ---@param classDef ClassDef
    ---@param propName stringn
    ---@param propDef PropertyDef
    local function saveProp(_, _, propName, propDef)
        local propID = propDef:saveToDB(nil, propName)
        self.ClassProps[propID] = propDef
    end

    local newClasses = {}

    for className, classDef in pairs(schemaDef) do
        local classID = self:getClassIdByName(className, false)
        if classID ~= 0 then
            error(string.format('Class %s already exists', className))
        end

        -- validate name
        if not self:isNameValid(className) then
            error('Invalid class name ' .. className)
        end

        if createVirtualTable == 0 then
            createVirtualTable = false
        elseif createVirtualTable == nil then
            createVirtualTable = self.config.createVirtualTable or false
        end

        if createVirtualTable then
            -- TODO Is this right way?

            -- Call virtual table creation
            local sqlStr = string.format("create virtual table [%s] using flexi_data ('%q');", className, classDef)
            self.db:exec(sqlStr)
            -- TODO Supply class ID
            --return string.format('Virtual flexi_data table [%s] created', className)
        else
            local clsObject = self.ClassDef { newClassName = className, data = classDef, DBContext = self }

            -- TODO Set ctloMask
            clsObject.D.ctloMask = 0
            clsObject.D.VirtualTable = false
            -- Check if class is fully resolved, i.e. does not have references to non-existing classes
            clsObject.D.Unresolved = false

            insertNewClass(self, clsObject)
            self:setNAMClass(clsObject)
            table_insert(newClasses, clsObject)
        end

        forEachNAMClassProp(applyProp)
        forEachNAMClassProp(saveProp)
    end

    for _, clsObject in ipairs(newClasses) do
        ClassDef.ApplyIndexing(nil, clsObject)
        clsObject:saveToDB()
    end

    self:applyNAMClasses()

    self.ActionQueue:run()
end

---@param self DBContext
---@param className string
---@param classDef table
---@param createVirtualTable boolean
---@return string @comment result of operation
local function createSingleClass(self, className, classDef, createVirtualTable)
    local schemaDef = { [className] = classDef }

    local savedActQue = self.ActionQueue == nil and self:setActionQueue() or self.ActionQueue
    local result, errMsg = pcall(createMultiClasses, self, schemaDef, createVirtualTable)
    if savedActQue ~= nil then
        self:setActionQueue(savedActQue)
    end

    if not result then
        error(errMsg)
    end

    return string.format('Class [%s] has been created', className)
end

--- Internal function to create class
---@param self DBContext
---@param className string
---@param classDef table @comment decoded JSON
---@param createVirtualTable boolean
--- Used to avoid multiple to/from JSON conversion
local function CreateClass(self, className, classDef, createVirtualTable)
    if type(classDef) == 'string' then
        classDef = json.decode(classDef)
    elseif not classDef then
        classDef = {
            properties = {},
            allowAnyProps = true,
        }
    end
    return createSingleClass(self, className, classDef, createVirtualTable)
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
    local classSchema = json.decode(schemaJson)

    local savedActQue = self.ActionQueue == nil and self:setActionQueue() or self.ActionQueue
    local result, errMsg = pcall(createMultiClasses, self, classSchema, createVirtualTable)
    if savedActQue ~= nil then
        self:setActionQueue(savedActQue)
    end

    if not result then
        error(errMsg)
    end

    local cnt = tablex.size(classSchema)
    return string.format('%d class(es) have been created', cnt)
end

return { CreateClass = CreateClass, CreateSchema = CreateSchema }
