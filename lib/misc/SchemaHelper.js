/**
 * Created by slanska on 2016-03-26.
 */
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports", 'lodash'], factory);
    }
})(function (require, exports) {
    /// <reference path="../../typings/lib.d.ts" />
    'use strict';
    var Sync = require('syncho');
    var _ = require('lodash');
    var SchemaHelper = (function () {
        function SchemaHelper(db, sourceSchema) {
            this.db = db;
            this.sourceSchema = sourceSchema;
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
                    return PROPERTY_TYPE.PROP_TYPE_INTEGER;
                case 'number':
                    return PROPERTY_TYPE.PROP_TYPE_NUMBER;
                case 'binary':
                    return PROPERTY_TYPE.PROP_TYPE_BINARY;
                case 'text':
                    return PROPERTY_TYPE.PROP_TYPE_TEXT;
                case 'boolean':
                    return PROPERTY_TYPE.PROP_TYPE_BOOLEAN;
                case 'object':
                    return PROPERTY_TYPE.PROP_TYPE_JSON;
                case 'date':
                    return PROPERTY_TYPE.PROP_TYPE_DATETIME;
                case 'enum':
                    return PROPERTY_TYPE.PROP_TYPE_ENUM;
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
            var c = self._targetClassProps;
            _.forEach(this.sourceSchema.allProperties, function (item, propName) {
                var propID = self.getNameID(propName);
                var cProp = {};
                cProp.rules = cProp.rules || {};
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
                        switch (cProp.rules.type) {
                            case PROPERTY_TYPE.PROP_TYPE_DATETIME:
                                if (item.time === false) {
                                    cProp.dateTime = 'dateOnly';
                                }
                                else {
                                    cProp.dateTime = 'dateTime';
                                }
                                break;
                            case PROPERTY_TYPE.PROP_TYPE_ENUM:
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
                        cProp.rules.type = PROPERTY_TYPE.PROP_TYPE_OBJECT;
                        var oneRel = self.sourceSchema.one_associations[propName];
                        cProp.reference = {};
                        cProp.reference.autoFetch = oneRel.autoFetch;
                        cProp.reference.autoFetchLimit = oneRel.autoFetchLimit;
                        cProp.reference.classID = self.getClassIDbyName(oneRel.model.table);
                        cProp.reference.reversePropertyID = oneRel.reverse;
                        break;
                    case 'hasMany':
                        // Generate relation
                        cProp.rules.type = PROPERTY_TYPE.PROP_TYPE_OBJECT;
                        var manyRel = self.sourceSchema.many_associations[propName];
                        cProp.reference = {};
                        cProp.reference.autoFetch = manyRel.autoFetch;
                        cProp.reference.autoFetchLimit = manyRel.autoFetchLimit;
                        cProp.reference.classID = self.getClassIDbyName(manyRel.model.table);
                        break;
                }
                c[item.name] = cProp;
            });
        };
        return SchemaHelper;
    }());
    exports.SchemaHelper = SchemaHelper;
});
//# sourceMappingURL=SchemaHelper.js.map