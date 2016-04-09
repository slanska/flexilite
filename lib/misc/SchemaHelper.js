/**
 * Created by slanska on 2016-03-26.
 */
/// <reference path="../../typings/lib.d.ts" />
'use strict';
var Sync = require('syncho');
var _ = require('lodash');
var SchemaHelper = (function () {
    function SchemaHelper(db, sourceSchema) {
        this.db = db;
        this.sourceSchema = sourceSchema;
        this._targetSchema = {};
        this._targetClassProps = {};
    }
    Object.defineProperty(SchemaHelper.prototype, "targetSchema", {
        get: function () {
            return this._targetSchema;
        },
        enumerable: true,
        configurable: true
    });
    ;
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
                return 1 /* INTEGER */;
            case 'number':
                return 3 /* NUMBER */;
            case 'binary':
                return 7 /* BINARY */;
            case 'text':
                return 0 /* TEXT */;
            case 'boolean':
                return 4 /* BOOLEAN */;
            case 'object':
                return 11 /* JSON */;
            case 'date':
                return 9 /* DATETIME */;
            case 'enum':
                return 6 /* ENUM */;
            default:
                throw new Error("Not supported property type: " + ormType);
        }
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
        self._targetSchema = {};
        var s = self._targetSchema;
        var c = self._targetClassProps;
        _.forEach(this.sourceSchema.allProperties, function (item, propName) {
            var propID = self.getNameID(propName);
            var sProp = item.ext || {};
            var cProp = {};
            cProp.rules = cProp.rules || {};
            sProp.map = sProp.map || {};
            cProp.ui = cProp.ui || {};
            switch (item.klass) {
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
                    // mapsTo allows to apply basic customization to schema mapping
                    if (!_.isEmpty(item.mapsTo) && !_.isEqual(item.mapsTo, propName))
                        sProp.map.jsonPath = "." + String(item.mapsTo);
                    else
                        sProp.map.jsonPath = "." + propID;
                    switch (cProp.rules.type) {
                        case 9 /* DATETIME */:
                            if (item.time === false) {
                                cProp.dateTime = 'dateOnly';
                            }
                            else {
                                cProp.dateTime = 'dateTime';
                            }
                            break;
                        case 6 /* ENUM */:
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
                    cProp.rules.type = 5 /* OBJECT */;
                    var oneRel = self.sourceSchema.one_associations[propName];
                    cProp.reference = {};
                    cProp.reference.autoFetch = oneRel.autoFetch;
                    cProp.reference.autoFetchLimit = oneRel.autoFetchLimit;
                    cProp.reference.classID = self.getClassIDbyName(oneRel.model.table);
                    cProp.reference.reversePropertyID = oneRel.reverse;
                    break;
                case 'hasMany':
                    // Generate relation
                    cProp.rules.type = 5 /* OBJECT */;
                    var manyRel = self.sourceSchema.many_associations[propName];
                    cProp.reference = {};
                    cProp.reference.autoFetch = manyRel.autoFetch;
                    cProp.reference.autoFetchLimit = manyRel.autoFetchLimit;
                    cProp.reference.classID = self.getClassIDbyName(manyRel.model.table);
                    break;
            }
            s[item.name] = sProp;
            c[item.name] = cProp;
        });
    };
    return SchemaHelper;
}());
exports.SchemaHelper = SchemaHelper;
//# sourceMappingURL=SchemaHelper.js.map