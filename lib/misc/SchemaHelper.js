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
    ///<reference path="../def/definitions.d.ts"/>
    /// <reference path="../../typings/node/node.d.ts"/>
    /// <reference path="../../node_modules/orm/lib/TypeScript/orm.d.ts" />
    /// <reference path="../../typings/tsd.d.ts" />
    'use strict';
    var Sync = require('syncho');
    var _ = require('lodash');
    /*
     Converts node-orm2 schema definition as it is passed to sync method,
     to Flexilite class and schema definitions
     */
    var Flexilite;
    (function (Flexilite) {
        var SchemaHelper = (function () {
            function SchemaHelper(db, sourceSchema) {
                this.db = db;
                this.sourceSchema = sourceSchema;
                this._targetSchema = {};
                this._targetClass = {};
            }
            Object.defineProperty(SchemaHelper.prototype, "targetSchema", {
                get: function () {
                    return this._targetSchema;
                },
                enumerable: true,
                configurable: true
            });
            ;
            Object.defineProperty(SchemaHelper.prototype, "targetClass", {
                get: function () {
                    return this._targetClass;
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
                        return 2 /* NUMBER */;
                    case 'binary':
                        return 6 /* BINARY */;
                    case 'text':
                        return 0 /* TEXT */;
                    case 'boolean':
                        return 3 /* BOOLEAN */;
                    case 'object':
                        return 4 /* OBJECT */;
                    case 'date':
                        return 8 /* DATETIME */;
                    case 'enum':
                        return 5 /* ENUM */;
                    default:
                        throw new Error("Not supported property type: " + ormType);
                }
            };
            // Expects to be running inside of Syncho call
            SchemaHelper.prototype.convert = function () {
                var self = this;
                if (!_.isFunction(self.getNameID))
                    throw new Error('getNameID() is not assigned');
                if (!_.isFunction(self.getClassIDbyName))
                    throw new Error('getClassIDbyName() is not assigned');
                self._targetClass = { properties: {} };
                self._targetSchema = { properties: {} };
                var s = self._targetSchema;
                var c = self._targetClass;
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
                                case 8 /* DATETIME */:
                                    if (item.time === false) {
                                        cProp.dateTime = 'dateOnly';
                                    }
                                    else {
                                        cProp.dateTime = 'dateTime';
                                    }
                                    break;
                                case 5 /* ENUM */:
                                    cProp.enumDef = { items: [] };
                                    _.forEach(item.items, function (enumItem) {
                                        var name = self.getNameID(enumItem);
                                        cProp.enumDef.items.push({ ID: name, NameID: name });
                                    });
                                    break;
                            }
                            s.properties[propID] = sProp;
                            c.properties[propID] = cProp;
                            break;
                        case 'hasOne':
                            // Generate relation
                            cProp.rules.type = 4 /* OBJECT */;
                            var oneRel = self.sourceSchema.one_associations[propName];
                            cProp.reference = {};
                            cProp.reference.autoFetch = oneRel.autoFetch;
                            cProp.reference.autoFetchLimit = oneRel.autoFetchLimit;
                            cProp.reference.type = 4 /* BOXED_REFERENCE */;
                            cProp.reference.classID = self.getClassIDbyName(oneRel.model.table);
                            cProp.reference.reversePropertyID = oneRel.reverse;
                            break;
                        case 'hasMany':
                            // Generate relation
                            cProp.rules.type = 4 /* OBJECT */;
                            var manyRel = self.sourceSchema.many_associations[propName];
                            cProp.reference = {};
                            cProp.reference.autoFetch = manyRel.autoFetch;
                            cProp.reference.autoFetchLimit = manyRel.autoFetchLimit;
                            cProp.reference.type = 1 /* LINKED_OBJECT */;
                            cProp.reference.classID = self.getClassIDbyName(manyRel.model.table);
                            break;
                    }
                });
            };
            return SchemaHelper;
        }());
        Flexilite.SchemaHelper = SchemaHelper;
    })(Flexilite || (Flexilite = {}));
    return Flexilite.SchemaHelper;
});
//# sourceMappingURL=SchemaHelper.js.map