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

local NullDBValueClass = class()

function NullDBValueClass:_init()

end

NullDBValueClass.__metatable = nil

function NullDBValueClass:boxed_index (idx)

end

function NullDBValueClass:boxed_newindex (value)
    error('Not assignable null value')
end

function NullDBValueClass:boxed_add(v1, v2)
    return nil
end

function NullDBValueClass:boxed_sub(v1, v2)
    return nil
end

function NullDBValueClass:boxed_mul(v1, v2)
    return nil
end

function NullDBValueClass:boxed_div(v1, v2)
end

function NullDBValueClass:boxed_pow(v1, v2)
    return nil
end

function NullDBValueClass:boxed_concat(v1, v2)
    return nil
end

function NullDBValueClass:boxed_len(v1, v2)
    return nil
end

function NullDBValueClass:boxed_tostring(v1)
    return nil
end

function NullDBValueClass:boxed_unm(v1)
    return nil
end

function NullDBValueClass:boxed_eq(v1, v2)
    return nil
end

function NullDBValueClass:boxed_lt(v1, v2)
    return nil
end

function NullDBValueClass:boxed_le(v1, v2)
    return nil
end

function NullDBValueClass:boxed_mod(v1, v2)
    return nil
end

-- Constant Null DBValue
local NullDBValue = NullDBValueClass()

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

---@param DBOV ReadOnlyDBOV
---@param propDef PropertyDef
function DBProperty:_init(DBOV, propDef)
    self.DBOV = assert(DBOV)
    self.PropDef = assert(propDef)
end

function DBProperty:Boxed()
    if not self.boxed then
        self.boxed = setmetatable({}, {
            __index = self.boxed_index,
            __newindex = self.boxed_newindex,
            __metatable = nil,
            __add = self.boxed_add,
            __sub = self.boxed_sub,
            __mul = self.boxed_mul,
            __div = self.boxed_div,
            __pow = self.boxed_pow,
            __concat = self.boxed_concat,
            __len = self.boxed_len,
            __tostring = self.boxed_tostring,
            __unm = self.boxed_unm,
            __eq = self.boxed_eq,
            __lt = self.boxed_lt,
            __le = self.boxed_le,
            __mod = self.boxed_mod,
        })
    end

    return self.boxed
end

---@param key string | number
function DBProperty:boxed_index(key)
    if type(key) == 'number' then
        local vv = self:GetValue(key)
        if vv then
            return vv.Boxed(self, key)
        end
        return NullDBValue
    elseif type(key) == 'string' then
        -- todo
        -- ref object property
    else
        --
    end
end

---@param key string | number
---@param value any
function DBProperty:boxed_newindex(key, value)
    return self:SetValue(key, value)
end

function DBProperty:boxed_add(v1, v2)
    -- TODO
    return self.GetValue(1).Boxed(self, 1).__add(v1, v2)
end

function DBProperty:boxed_sub(v1, v2)
end

function DBProperty:boxed_mul(v1, v2)
end

function DBProperty:boxed_div(v1, v2)
end

function DBProperty:boxed_pow(v1, v2)
end

function DBProperty:boxed_concat(v1, v2)
end

function DBProperty:boxed_len(v1, v2)
end

function DBProperty:boxed_tostring(boxed, v1)
    -- TODO
    return tostring(v1)
end

function DBProperty:boxed_unm(v1)
end

function DBProperty:boxed_eq(v1, v2)
end

function DBProperty:boxed_lt(v1, v2)
end

function DBProperty:boxed_le(v1, v2)
end

function DBProperty:boxed_mod(v1, v2)
end

---@param idx number @comment 1 based index
---@param val any
function DBProperty:SetValue(idx, val)
    error(string.format('Cannot modify readonly version of %s.%s',
                        self.PropDef.ClassDef.Name.text, self.PropDef.Name.text))
end

---@param idx number @comment 1 based
function DBProperty:GetValue(idx)
    ---->>
    --if self.PropDef.ID == nil then
    --    require('pl.pretty').dump(self.PropDef)
    --end

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
        return NullDBValue
    end

    return self.values[idx]
end

-- Returns all values as table or scalar value, depending on property's maxOccurrences
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
        result.Value = val
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
        return self:getOriginalProperty():GetValue(idx)
    end

    return self.values[idx]
end

local refValSQL = {
    -- TODO insert
    [Constants.OPERATION.CREATE] = [[insert or replace into [.ref-values]
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

-- Saves values to the database
function ChangedDBProperty:SaveToDB()
    local DBContext = self.DBOV.ClassDef.DBContext

    ---@param values table<number, DBValue>
    local function insertRefValues(values)
        for propIndex, dbv in pairs(values) do

            local status, err = xpcall(function()
                local vv = self.PropDef:GetRawValue(dbv)
                local params = {
                    ObjectID = self.DBOV.ID,
                    PropertyID = self.PropDef.ID,
                    PropIndex = propIndex,
                    Value = vv,
                    ctlv = dbv.ctlv or 0,
                    MetaData = dbv.MetaData and JSON.encode(dbv.MetaData) or nil }
                DBContext:execStatement(refValSQL[Constants.OPERATION.CREATE], params)
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
    NullDBValue = NullDBValue
}
