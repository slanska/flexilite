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
    ///<reference path="../models/definitions.d.ts"/>
    /// <reference path="../../typings/node/node.d.ts"/>
    /// <reference path="../../node_modules/orm/lib/TypeScript/orm.d.ts" />
    /// <reference path="../../typings/tsd.d.ts" />
    'use strict';
    var Sync = require('syncho');
    var _ = require('lodash');
    /*
     Converts node-orm2 schema definition to Flexilite format
     */
    var Flexilite;
    (function (Flexilite) {
        var SchemaConverter = (function () {
            function SchemaConverter(db, sourceSchema) {
                this.db = db;
                this.sourceSchema = sourceSchema;
                this._targetSchema = {};
            }
            Object.defineProperty(SchemaConverter.prototype, "targetSchema", {
                get: function () {
                    return this._targetSchema;
                },
                enumerable: true,
                configurable: true
            });
            ;
            SchemaConverter.nodeOrmTypeToFlexiliteType = function (ormType) {
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
            SchemaConverter.prototype.convert = function () {
                var _this = this;
                if (!_.isFunction(this.getNameID))
                    throw new Error('getNameID() is not assigned');
                var t = this._targetSchema;
                t.properties = {};
                _.forEach(this.sourceSchema.allProperties, function (item, propName) {
                    var propID = _this.getNameID(propName);
                    var prop = item.ext || {};
                    prop.rules = prop.rules || {};
                    prop.map = prop.map || {};
                    prop.ui = prop.ui || {};
                    switch (item.klass) {
                        case 'primary':
                            prop.rules.type = SchemaConverter.nodeOrmTypeToFlexiliteType(item.type);
                            if (item.size)
                                prop.rules.maxLength = item.size;
                            t.properties[propID] = prop;
                            break;
                        case 'hasOne':
                            break;
                        case 'hasMany':
                            break;
                    }
                });
            };
            return SchemaConverter;
        }());
        Flexilite.SchemaConverter = SchemaConverter;
    })(Flexilite || (Flexilite = {}));
    return Flexilite.SchemaConverter;
});
//# sourceMappingURL=schemaConverter.js.map