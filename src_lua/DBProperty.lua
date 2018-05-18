---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by slanska.
--- DateTime: 2018-01-12 5:37 PM
---

--[[
DBProperty and derived classes.
Used by DBObject/*DBOV to access object property values

Provides access to Boxed(), to be called from custom scripts and functions
Hold list of DBValue items, one item per .ref-value row (or A..P columns in .objects row)
]]

local class = require 'pl.class'
local DBValue = require 'DBValue'
local tablex = require 'pl.tablex'
local Constants = require 'Constants'
local JSON = require 'cjson'

-------------------------------------------------------------------------------
--[[
DBProperty
Provides access to simple values (both scalar and vector)
]]
-------------------------------------------------------------------------------
---@class DBProperty
---@field DBOV ReadOnlyDBOV @comment DB Object Version
---@field PropDef PropertyDef
local DBProperty = class()

---@class DBPropertyBoxed: DBValueBoxed
local DBPropertyBoxed = class(DBValue.BoxedClass)

function DBPropertyBoxed:getValue1()
    local vv = self.Prop:GetValue(1)
    if vv then
        return vv.Value
    end
    return DBValue.Null
end

---@param prop DBProperty
function DBPropertyBoxed:_init(prop)
    self:super(DBPropertyBoxed.getValue1, prop, 1)
end

function DBPropertyBoxed:__index(key)
    if type(key) == 'number' then
        local vv = self:GetValue(key)
        if vv then
            return vv.Boxed(self, key)
        end
        return DBValue.Null
    elseif type(key) == 'string' then
        -- todo
        -- ref object property
    else
        --
    end
end

function DBPropertyBoxed:__newindex(key, value)
    return self:SetValue(key, value)
end

function DBPropertyBoxed:__len(self, v1)

end

---@param DBOV ReadOnlyDBOV
---@param propDef PropertyDef
function DBProperty:_init(DBOV, propDef)
    self.DBOV = assert(DBOV)
    self.PropDef = assert(propDef)
end

function DBProperty:Boxed()
    if not self.boxed then
        self.boxed = DBPropertyBoxed(self)
    end

    return self.boxed
end

---@param idx number @comment 1 based index
---@param val any
function DBProperty:SetValue(idx, val)
    error(string.format('Cannot modify readonly version of %s.%s',
            self.PropDef.ClassDef.Name.text, self.PropDef.Name.text))
end

---@param idx number @comment 1 based
---@return DBValue
function DBProperty:GetValue(idx)
    self.PropDef.ClassDef.DBContext.AccessControl:ensureCurrentUserAccessForProperty(
            self.PropDef.ID, Constants.OPERATION.READ)

    idx = idx or 1

    if not self.values then
        self.values = {}
    end

    ---@type DBValue
    local v = self.values[idx]

    if v then
        return v
    end

    -- load from db
    local sql = [[select * from [.ref-values]
            where ObjectID = :ObjectID and PropertyID = :PropertyID and PropIndex <= :PropIndex
            order by ObjectID, PropertyID, PropIndex;]]
    for row in self.DBOV.ClassDef.DBContext:loadRows(sql, { ObjectID = self.DBOV.ID,
                                                            PropertyID = self.PropDef.ID, PropIndex = idx }) do
        -- TODO what if index 1 is set in .ref-values and in .objects[A..P]? Override? Ignore?
        table.insert(self.values, row.PropIndex, DBValue(row))
    end

    if not self.values[idx] then
        return DBValue.Null
    end

    return self.values[idx]
end

-- Returns all values as array or scalar value (depending on property's maxOccurrences)
-- Values are returned in user-friendly format (e.g. blobs as base64 strings)
function DBProperty:GetValues()
    local maxOccurr = (self.PropDef.D and self.PropDef.D.rules and self.PropDef.D.rules.maxOccurrences) or 1
    if maxOccurr > 1 then
        local result = {}
        if self.values then
            for
            ---@type number
            ii,
            ---@type DBValue
            dbv in pairs(self.values) do
                -- TODO Handle references
                table.insert(result, ii, dbv.Value)
            end
        end
        return result
    else
        return self:GetValue(1).Value
    end
end

---@param idx number
---@return DBValue
function DBProperty:cloneValue(idx)
    return tablex.deepcopy(assert(self.values[idx]))
end

--
function DBProperty:ExportValues()
    if self.values == nil then
        return nil
    end

    if self.PropDef.D.rules.maxOccurrences then

    end

    local result = {}
    for i, dbv in ipairs(self.values) do
        table.insert(result, self.PropDef:ExportDBValue(self.DBOV.DBObject, dbv))
    end
    return result
end

-------------------------------------------------------------------------------
--[[
ChangedDBProperty
Used by WritableDBOV (DBObject.curVer)
]]
-------------------------------------------------------------------------------
---@class ChangedDBProperty
---@field DBOV WritableDBOV
---@field PropDef PropertyDef
local ChangedDBProperty = class(DBProperty)

function ChangedDBProperty:_init(DBOV, propDef)
    self:super(DBOV, propDef)
end

-- Internal method to get access to original counterpart property
---@return DBProperty | nil
function ChangedDBProperty:getOriginalProperty()
    if self.DBOV.DBObject.state == Constants.OPERATION.CREATE then
        return nil
    end
    local result = self.DBOV.DBObject.origVer:getProp(self.PropDef.Name.text)
    if not result then
        error(string.format('DBProperty %s.%s not found',
                self.DBOV.ClassDef.Name.text, self.PropDef.Name.text))
    end
    return result
end

---@param idx number @comment 1 based index
---@param val any
function ChangedDBProperty:SetValue(idx, val)
    local maxOccurr = self.PropDef.D.rules.maxOccurrences or Constants.MAX_INTEGER
    if idx > maxOccurr then
        error(string.format('%s.%s: maxOccurrences rule violation (%d > %d)',
                self.PropDef.ClassDef.Name.text, self.PropDef.Name.text, idx, maxOccurr))
    end

    if not self.values then
        self.values = {}
    end

    local result = self.values[idx]
    if not result then
        self.PropDef.ClassDef.DBContext.AccessControl:ensureCurrentUserAccessForProperty(
                self.PropDef.ID, self.DBOV.DBObject.state)
        local prop = self:getOriginalProperty()
        if prop then
            result = prop:cloneValue(idx)
        else
            result = DBValue {  }
        end
        self.values[idx] = result
    end

    if result then
        self.PropDef:ImportDBValue(result, val)
    else
        self.PropDef.ClassDef.DBContext.AccessControl:ensureCurrentUserAccessForProperty(
                self.PropDef.ID, idx == 1 and Constants.OPERATION.UPDATE or Constants.OPERATION.CREATE)
        -- is not set - create new one
        result = DBValue { Value = val }
        self.values[idx] = result
    end
end

---@param idx number @comment 1 based index
---@return DBValue
function ChangedDBProperty:GetValue(idx)
    idx = idx or 1

    if not self.values or not self.values[idx] then
        local orig = self:getOriginalProperty()
        if orig then
            local vv = orig.GetValue
            if vv then
                return vv(self, idx)
            end
        end
        return DBValue.Null
    end

    return self.values[idx]
end

local refValSQL = {
    [Constants.OPERATION.CREATE] = [[insert into [.ref-values]
    (ObjectID, PropertyID, PropIndex, [Value], ctlv, MetaData) values
    (:ObjectID, :PropertyID, :PropIndex, :Value, :ctlv, :MetaData);]],

    [Constants.OPERATION.UPDATE] = [[update [.ref-value] set Value=:Value, ctlv=:ctlv, PropIndex=:PropIndex
      MetaData=:MetaData where ObjectID=:old_ObjectID and PropertyID=:old_PropertyID
      and PropIndex=:old_PropIndex;]],

    ['UX'] = [[update [.ref-value] set Value=:Value, ctlv=:ctlv, PropIndex=:PropIndex
      MetaData=:MetaData, ObjectID=:ObjectID, PropertyID=:PropertyID, PropIndex=:PropIndex
      where ObjectID=:old_ObjectID and PropertyID=:old_PropertyID
      and PropIndex=:old_PropIndex;]],

    [Constants.OPERATION.DELETE] = [[delete from [.ref-values]
    where ObjectID=:old_ObjectID and PropertyID=:old_PropertyID
      and PropIndex=:old_PropIndex;]],
}

-- Updates ctlv value of DBValue, in according to PropDef definition and current Value
---@param dbv DBValue
function ChangedDBProperty:updateCTLV(dbv)

end

-- Saves values to the database
function ChangedDBProperty:SaveToDB()
    local DBContext = self.DBOV.ClassDef.DBContext

    ---@param values table<number, DBValue>
    local function insertRefValues(values)
        assert(values)

        for propIndex, dbv in pairs(values) do

            local status, err = xpcall(function()
                local vv = self.PropDef:GetRawValue(dbv)

                local save, deferredAction = self.PropDef:BeforeDBValueSave(dbv)
                if save then
                    local params = {
                        ObjectID = self.DBOV.ID,
                        PropertyID = self.PropDef.ID,
                        PropIndex = propIndex,
                        Value = vv,
                        ctlv = dbv.ctlv or 0,
                        MetaData = dbv.MetaData and JSON.encode(dbv.MetaData) or nil }

                    DBContext:execStatement(refValSQL[Constants.OPERATION.CREATE], params)
                end

                if deferredAction then
                    -- TODO
                end
            end,
                    function(err)
                        return err
                    end)
            if not status then
                local errMsg = tostring(err)
                error(string.format('%s.%s (%d)[%d]:%d %s',
                        self.PropDef.ClassDef.Name.text, self.PropDef.Name.text, self.PropDef.ID, propIndex,
                        self.DBOV.ID, errMsg))
            end
        end
    end

    ---@param orig_prop DBProperty
    ---@param values table<number, DBValue>
    local function deleteRefValues(orig_prop, values)
        for propIndex, dbv in pairs(values) do
            DBContext:execStatement(refValSQL[Constants.OPERATION.DELETE],
                    { old_ObjectID = orig_prop.DBOV.ID,
                      old_PropertyID = orig_prop.PropDef.ID,
                      old_PropIndex = propIndex })
        end
    end

    local op = self.DBOV.DBObject.state
    if op == Constants.OPERATION.UPDATE then
        local old_values = {}
        local orig_prop = self.DBOV.DBObject.origVer:getProp(self.PropDef.Name.text)
        if orig_prop then
            old_values = orig_prop.values

            ---@type table<number, DBValue>
            local added_values = tablex.difference(self.values, old_values)

            ---@type table<number, DBValue>
            local updated_values = tablex.intersection(self.values, old_values)

            ---@type table<number, DBValue>
            local deleted_values = tablex.difference(old_values, self.values)
            for propIndex, dbv in pairs(self.values) do
                if dbv.Value == nil and deleted_values[propIndex] == nil then
                    deleted_values[propIndex] = dbv
                end
            end

            deleteRefValues(orig_prop, deleted_values)

            for propIndex, dbv in pairs(updated_values) do
                local vv = self.PropDef:GetRawValue(dbv)

                local save, deferredAction = self.PropDef:BeforeDBValueSave(dbv)

                if save then
                    if self.DBOV.ID ~= orig_prop.DBOV.ID then
                        DBContext:execStatement(refValSQL['UX'],
                                { old_ObjectID = orig_prop.DBOV.ID,
                                  old_PropertyID = orig_prop.PropDef.ID,
                                  old_PropIndex = propIndex,
                                  ObjectID = self.DBOV.ID,
                                  PropertyID = self.PropDef.ID,
                                  PropIndex = propIndex,
                                  Value = vv,
                                  ctlv = dbv.ctlv or 0,
                                  MetaData = dbv.MetaData and JSON.encode(dbv.MetaData) or nil })
                    else
                        DBContext:execStatement(refValSQL[Constants.OPERATION.UPDATE],
                                {
                                    ObjectID = self.DBOV.ID,
                                    PropertyID = self.PropDef.ID,
                                    PropIndex = propIndex,
                                    Value = vv,
                                    ctlv = dbv.ctlv or 0,
                                    MetaData = dbv.MetaData and JSON.encode(dbv.MetaData) or nil })
                    end
                end

                if deferredAction then
                    -- TODO
                end
            end

            insertRefValues(added_values)
        else
            -- no old property, therefore all values are new
            insertRefValues(self.values)
        end
    elseif op == Constants.OPERATION.CREATE then
        insertRefValues(self.values)
    elseif op == Constants.OPERATION.DELETE then
        deleteRefValues(self, self.values)
    end
end

return {
    DBProperty = DBProperty,
    ChangedDBProperty = ChangedDBProperty,
}
