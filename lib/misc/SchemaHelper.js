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
     to Flexilite format
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
                        return 1 /* integer */;
                    case 'number':
                        return 2 /* number */;
                    case 'binary':
                        return 6 /* binary */;
                    case 'text':
                        return 0 /* text */;
                    case 'boolean':
                        return 3 /* boolean */;
                    case 'object':
                        return 4 /* reference */;
                    case 'date':
                        return 7 /* date */;
                    case 'enum':
                        return 5 /* ENUM */;
                    default:
                        throw new Error("Not supported property type: " + ormType);
                }
            };
            // Expects to be running inside of Syncho call
            SchemaHelper.prototype.convert = function () {
                var _this = this;
                if (!_.isFunction(this.getNameID))
                    throw new Error('getNameID() is not assigned');
                this._targetClass = { properties: {} };
                this._targetSchema = { properties: {} };
                var s = this._targetSchema;
                var c = this._targetClass;
                _.forEach(this.sourceSchema.allProperties, function (item, propName) {
                    var propID = _this.getNameID(propName);
                    var sProp = item.ext || {};
                    var cProp = {};
                    cProp.rules = cProp.rules || {};
                    cProp.map = cProp.map || {};
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
                            if (item.mapsTo && !_.isEqual(item.mapsTo, propName))
                                cProp.columnNameID = _this.getNameID(item.mapsTo);
                            // TODO item.big
                            // TODO item.time
                            s.properties[propID] = sProp;
                            c.properties[propID] = cProp;
                            break;
                        case 'hasOne':
                            // Generate relation
                            sProp.rules.type = 4 /* reference */;
                            //this.sourceSchema.one_associations[propName].
                            //sProp.referenceTo =
                            break;
                        case 'hasMany':
                            // Generate relation
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