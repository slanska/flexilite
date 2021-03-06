---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by slan_ska.
--- DateTime: 2018-10-17 7:14 PM
---
---
local normalizeSqlName = require('Util').normalizeSqlName
local List = require 'pl.List'
local Constants = require 'Constants'
local format = string.format

--- Appends subquery for user-defined columns to instead of trigger body
---@param sql table @comment pl.List
---@param classDef ClassDef
---@param udidProp PropertyDef
---@param colName string
---@param op string @comment new, old
local function appendUDIDtoTrigger(sql, classDef, udidProp, colName, op)
    if udidProp ~= nil then
        sql:append(format('coalesce(%s.[%s], ', op, colName))
        if udidProp.ColMap ~= nil and classDef.ColMapActive then
            local mask = classDef.DBContext.ClassDef.getCtloMaskForColMapIndex(udidProp)
            sql:append(format(
                    '(select ObjectID from [.objects] where ClassID = %d and %s = %s.[%s_2] and ctlo & %d = %d limit 1)',
                    classDef.ClassID, udidProp.ColMap, op, colName, mask, mask))
        else
            sql:append(format(
                    '(select ObjectID from [.ref-values] where PropertyID = %d and [Value] = %s.[%s_2] and ctlv & %d <> 0)',
                    udidProp.ID, op, colName, Constants.CTLV_FLAGS.UNIQUE))
        end

        sql:append ')'
    end
end

--- Generates SQL for dropping view
---@param tableName string
---@return string @comment generated SQL
local function generateDropViewSql(tableName)
    local result = format('drop view if exists [%s];', tableName)
    return result
end

--- Regenerates updatable view to deal for flexirel
---@param self DBContext
---@param tableName string
---@param className string
---@param propName string
---@param col1Name string
---@param col2Name string
--- may throw error
local function generateView(self, tableName, className, propName, col1Name, col2Name)

    -- Normalize class and prop names
    className = normalizeSqlName(className)
    propName = normalizeSqlName(propName)
    col1Name = normalizeSqlName(col1Name)
    col2Name = normalizeSqlName(col2Name)

    -- check permission to create/open new tables
    self.AccessControl:ensureUserCanCreateClass(self.UserInfo)

    -- get class
    local fromClassDef = self:getClassDef(className, true)

    -- get reference property
    local fromPropDef = fromClassDef:getProperty(propName)

    local toClassDef = self:getClassDef(fromPropDef.D.refDef.classRef.text, true)

    -- ensure that this is reference property
    if not fromPropDef.D.refDef or not fromPropDef:isReference() or fromPropDef.D.refDef.mixin then
        error(format('[%s].[%s] must be a pure reference property', className, propName))
    end

    -- Check if there is reverse property defined. If so, IDs of both ref properties will be compared to
    -- determine how ObjectID and Value columns in .ref-values to be mapped. Lower property ID will be used
    -- for <from> property, and higher ID - for <to> property. If reverse property is not defined, original
    -- property will be used for <from>
    local toPropDef = nil
    if fromPropDef.D.refDef.reverseProperty then
        toPropDef = toClassDef:getProperty(fromPropDef.D.refDef.reverseProperty.text)
    end

    if toPropDef then
        assert(toPropDef.ID, ('%s does not have ID'):format(toPropDef:debugDesc()))
    end
    if fromPropDef then
        assert(fromPropDef.ID, ('%s does not have ID'):format(fromPropDef:debugDesc()))
    end

    if toPropDef and toPropDef.ID < fromPropDef.ID then
        toPropDef, fromPropDef = fromPropDef, toPropDef
        toClassDef, fromClassDef = fromClassDef, toClassDef
    end

    -- attempt to get (optional) user defined ID properties
    local toUDID = toClassDef:getUdidProp()
    local fromUDID = fromClassDef:getUdidProp()

    local sql = List()
    -- View
    sql:append(generateDropViewSql(tableName))
    sql:append '' -- new line
    sql:append(format('create view if not exists [%s] as select v.%s as %s, v.%s as %s',
            tableName, col1Name, col1Name, col2Name, col2Name))

    --- Appends subquery for user-defined columns to view body
    ---@param udidProp PropertyDef
    ---@param colName string
    local function appendUDIDtoView(udidProp, colName)
        if udidProp ~= nil then
            sql:append ','
            if udidProp.ColMap ~= nil then
                sql:append(format('(select o.[%s] from [.objects] o where o.ObjectID = v.[%s] limit 1) as [%s_2]',
                        udidProp.ColMap, colName, colName))
            else
                sql:append(format([[(select ObjectID from [.ref-values] where PropertyID = %d
                and ctlv & %d <> 0 and [Value] = v.[%s]) as [%s_2] ]],
                        udidProp.ID, Constants.CTLV_FLAGS.INDEX_AND_REFS_MASK, colName, colName))
            end
        end
    end

    appendUDIDtoView(fromUDID, col1Name)
    appendUDIDtoView(toUDID, col2Name)

    assert(fromPropDef.ID, format('Property.ID is not yet set (%s)', fromPropDef.Name.text))

    sql:append(format('from (select ObjectID as [%s], [Value] as [%s] from [.ref-values] where PropertyID = %d and ctlv & %d <> 0) v;',
            col1Name, col2Name, fromPropDef.ID, Constants.CTLV_FLAGS.INDEX_AND_REFS_MASK))

    -- Insert trigger
    sql:append '' -- new line
    sql:append(format(
            [[create trigger [%s_insert]
        instead of insert on [%s] for each row
        begin]],
            tableName, tableName))

    local function appendInsertStatement()

        --[[
        resulting insert sql looks like this (unfortunately CTE is not supporte in SQLite triggers, so we
        use a bit complicated subqueries instead):
        insert into .ref-values select col1, col2, (select max(PropIndex) + 1)... from (select coalesce(col1), coalesce(col2))
        ]]
        sql:append(format(
                [[insert into [.ref-values] (ObjectID, [Value], PropIndex, PropertyID, ctlv, Metadata)
            select v.[%s], v.[%s], coalesce((select max(PropIndex) from [.ref-values] where ObjectID = v.[%s]
            and [Value] = v.[%s] and ctlv and %d <> 0), 0) + 1, ]],
                col1Name, col2Name, col1Name, col2Name, Constants.CTLV_FLAGS.ALL_REFS_MASK))
        sql:append(format('%d, %d, null ', fromPropDef.ID, fromPropDef.ctlv))

        sql:append(' from (select ')
        appendUDIDtoTrigger(sql, fromClassDef, fromUDID, col1Name, 'new')
        sql:append(format(' as [%s], ', col1Name))
        appendUDIDtoTrigger(sql, toClassDef, toUDID, col2Name, 'new')
        sql:append(format(' as [%s]', col2Name))

        sql:append(') v;')
    end

    local function appendDeleteStatement()
        sql:append(format('delete from [.ref-values] where  ObjectID = '))
        appendUDIDtoTrigger(sql, fromClassDef, fromUDID, col1Name, 'old')
        sql:append(' and [Value] = ')
        appendUDIDtoTrigger(sql, toClassDef, toUDID, col2Name, 'old')
        sql:append(format(' and ctlv & %d <> 0;', Constants.CTLV_FLAGS.ALL_REFS_MASK))
    end

    appendInsertStatement()
    sql:append [[end;]]
    sql:append '' -- new line

    -- Update trigger
    sql:append(format(
            [[create trigger [%s_update]
        instead of update on [%s] for each row]],
            tableName, tableName))

    ---@param prefix string
    ---@param colName string
    local function appendWhenCondition(prefix, colName)
        sql:append(format(
                ' %s (new.[%s] is not null and new.[%s] <> old.[%s])',
                prefix, colName, colName, colName))
    end

    appendWhenCondition('when', col1Name)
    appendWhenCondition('or', col2Name)
    if fromUDID then
        appendWhenCondition('or', col1Name .. '_2')
    end
    if toUDID then
        appendWhenCondition('or', col2Name .. '_2')
    end

    sql:append('begin')
    appendDeleteStatement()
    appendInsertStatement()

    sql:append('end;')

    -- Delete trigger
    sql:append '' -- new line
    sql:append(format(
            [[create trigger [%s_delete]
        instead of delete on [%s] for each row
        begin]],
            tableName, tableName))
    appendDeleteStatement()

    sql:append('end;')

    local sqlText = sql:join('\n')
    local sqlResult = self.db:exec(sqlText)
    if sqlResult ~= 0 then
        local errMsg = format("%d: %s", self.db:error_code(), self.db:error_message())
        error(errMsg)
    end
end

return {
    generateView = generateView,
    generateDropViewSql = generateDropViewSql,
}
