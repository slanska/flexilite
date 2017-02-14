/**
 * Created by slanska on 2016-03-26.
 */
/// <reference path="../../typings/lib.d.ts" />
'use strict';
var Sync = require('syncho');
var _ = require('lodash');
/*
 Helper class for converting node-orm2 schema to Flexilite schema
 */
var SchemaHelper = (function () {
    function SchemaHelper(db, sourceSchema, columnNameMap) {
        this.db = db;
        this.sourceSchema = sourceSchema;
        this.columnNameMap = columnNameMap;
        this._targetClassProps = {};
    }
    Object.defineProperty(SchemaHelper.prototype, "targetClassProps", {
        get: function () {
            return this._targetClassProps;
        },
        enumerable: true,
        configurable: true
    });
    SchemaHelper.nodeOrmTypeToFlexiliteType = function (ormType) {
        var result;
        switch (ormType.toLowerCase()) {
            case 'serial':
            case 'integer':
                return 15 /* PROP_TYPE_INTEGER */;
            case 'number':
                return 20 /* PROP_TYPE_NUMBER */;
            case 'binary':
                return 23 /* PROP_TYPE_BINARY */;
            case 'text':
                return 25 /* PROP_TYPE_TEXT */;
            case 'boolean':
                return 19 /* PROP_TYPE_BOOLEAN */;
            case 'object':
                return 26 /* PROP_TYPE_JSON */;
            case 'date':
                return 21 /* PROP_TYPE_DATETIME */;
            case 'enum':
                return 16 /* PROP_TYPE_ENUM */;
            default:
                throw new Error("Not supported property type: " + ormType);
        }
    };
    SchemaHelper.prototype.convertProperty = function (item, propName, itemKind) {
        var self = this;
        // Handle column name mapping
        if (self.columnNameMap) {
            var colMap = self.columnNameMap[propName];
            if (_.isEmpty(colMap))
                return;
            propName = colMap;
        }
        var propID = self.getNameID(propName);
        var cProp = {};
        cProp.rules = cProp.rules || {};
        cProp.ui = cProp.ui || {};
        switch (itemKind) {
            case 'primary':
                cProp.rules.type = SchemaHelper.nodeOrmTypeToFlexiliteType(item.type);
                if (item.size)
                    cProp.rules.maxLength = item.size;
                if (item.defaultValue)
                    cProp.defaultValue = item.defaultValue;
                if (item.unique || item.indexed) {
                    cProp.unique = item.unique;
                    cProp.indexed = true;
                }
                switch (cProp.rules.type) {
                    case 21 /* PROP_TYPE_DATETIME */:
                        if (item.time === false) {
                            cProp.dateTime = 'dateOnly';
                        }
                        else {
                            cProp.dateTime = 'dateTime';
                        }
                        break;
                    case 16 /* PROP_TYPE_ENUM */:
                        cProp.enumDef = { items: [] };
                        _.forEach(item.items, function (enumItem) {
                            var name = self.getNameID(enumItem);
                            cProp.enumDef.items.push({ ID: name, TextID: name });
                        });
                        break;
                }
                break;
            case 'hasOne':
                // Generate relation
                cProp.rules.type = 4 /* PROP_TYPE_OBJECT */;
                var oneRel = self.sourceSchema.one_associations[propName];
                cProp.reference = {};
                cProp.reference.autoFetch = oneRel.autoFetch;
                cProp.reference.autoFetchLimit = oneRel.autoFetchLimit;
                cProp.reference.classID = self.getClassIDbyName(oneRel.model.table);
                cProp.reference.reversePropertyID = oneRel.reverse;
                break;
            case 'hasMany':
                // Generate relation
                cProp.rules.type = 4 /* PROP_TYPE_OBJECT */;
                var manyRel = self.sourceSchema.many_associations[propName];
                cProp.reference = {};
                cProp.reference.autoFetch = manyRel.autoFetch;
                cProp.reference.autoFetchLimit = manyRel.autoFetchLimit;
                cProp.reference.classID = self.getClassIDbyName(manyRel.model.table);
                break;
        }
        return cProp;
    };
    /*
     Converts node-orm2 model definition as it is passed to sync() method,
     to Flexilite structure. Result is placed to targetClass and targetSchema properties
     which are dictionaries set property name.
     NOTE: Expects to be running inside of Syncho call
     */
    SchemaHelper.prototype.convertFromNodeOrmSync = function () {
        var self = this;
        if (!_.isFunction(self.getNameID))
            throw new Error('getNameID() is not assigned');
        if (!_.isFunction(self.getClassIDbyName))
            throw new Error('getClassIDbyName() is not assigned');
        self._targetClassProps = {};
        var c = self._targetClassProps;
        _.forEach(this.sourceSchema.properties, function (item, propName) {
            var cProp = self.convertProperty(item, propName, 'primary');
            c[item.name] = cProp;
        });
        _.forEach(this.sourceSchema.one_associations, function (item, propName) {
            // TODO
        });
        _.forEach(this.sourceSchema.many_associations, function (item, propName) {
            // TODO
        });
        // TODO Custom types
    };
    return SchemaHelper;
}());
exports.SchemaHelper = SchemaHelper;
//# sourceMappingURL=SchemaHelper.js.map