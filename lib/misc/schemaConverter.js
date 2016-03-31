/**
 * Created by slanska on 2016-03-26.
 */
///<reference path="../models/definitions.d.ts"/>
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
    var SchemaConverter = (function () {
        function SchemaConverter(db, sourceSchema) {
            this.db = db;
            this.sourceSchema = sourceSchema;
            this._targetSchema = {};
            this._targetCollectionSchema = {};
        }
        Object.defineProperty(SchemaConverter.prototype, "targetSchema", {
            get: function () {
                return this._targetSchema;
            },
            enumerable: true,
            configurable: true
        });
        ;
        Object.defineProperty(SchemaConverter.prototype, "targetCollectionShema", {
            get: function () {
                return this._targetCollectionSchema;
            },
            enumerable: true,
            configurable: true
        });
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
            this._targetCollectionSchema = { properties: {} };
            this._targetSchema = { properties: {} };
            var s = this._targetSchema;
            var c = this._targetCollectionSchema;
            _.forEach(this.sourceSchema.allProperties, function (item, propName) {
                var propID = _this.getNameID(propName);
                var sProp = item.ext || {};
                sProp.rules = sProp.rules || {};
                sProp.map = sProp.map || {};
                sProp.ui = sProp.ui || {};
                var cProp = {};
                switch (item.klass) {
                    case 'primary':
                        sProp.rules.type = SchemaConverter.nodeOrmTypeToFlexiliteType(item.type);
                        if (item.size)
                            sProp.rules.maxLength = item.size;
                        if (item.defaultValue)
                            sProp.defaultValue = item.defaultValue;
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
        return SchemaConverter;
    }());
    Flexilite.SchemaConverter = SchemaConverter;
})(Flexilite || (Flexilite = {}));
module.exports = Flexilite.SchemaConverter;
//# sourceMappingURL=schemaConverter.js.map