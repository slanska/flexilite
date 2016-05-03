/**
 * Created by slanska on 2016-03-04.
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
    var ReverseEngine = (function () {
        function ReverseEngine(db) {
            this.db = db;
        }
        /*
    
         */
        ReverseEngine.sqliteTypeToOrmType = function (type) {
            if (_.isNull(type))
                return { type: 'text' };
            switch (type.toLowerCase()) {
                case 'text':
                    return { type: 'text' };
                case 'numeric':
                case 'real':
                    return { type: 'number' };
                case 'bool':
                    return { type: 'boolean' };
                case 'json1':
                    return { type: 'object' };
                case 'date':
                    return { type: 'date', time: false };
                case 'datetime':
                    return { type: 'date', time: true };
                case 'blob':
                    return { type: 'binary' };
                case 'integer':
                    return { type: 'integer' };
                default:
                    var regx = /([^)]+)\(([^)]+)\)/;
                    var matches = regx.exec(type.toLowerCase());
                    if (matches.length === 3) {
                        if (matches[1] === 'blob')
                            return { type: 'binary', size: Number(matches[2]) };
                        if (matches[1] === 'numeric') {
                            return { type: 'number' };
                        }
                        return { type: 'text', size: Number(matches[2]) };
                    }
                    return { type: 'text' };
            }
        };
        /*
    
         */
        ReverseEngine.prototype.getPropertiesFromORMDriverSchema = function (schema) {
            var result = {};
            _.forEach(schema.properties, function (prop) {
                result[prop.name] = prop;
            });
            return result;
        };
        /*
         Retrieves all database metadata and returns array of model definitions in the format
         expected by node-orm2 Driver.
         Expected to be run inside Sync() call
         */
        ReverseEngine.prototype.loadSchemaFromDatabase = function () {
            var self = this;
            var result = {};
            var tables = self.db.all.sync(self.db, "select * from sqlite_master where type = 'table' and name not like 'sqlite%';");
            _.forEach(tables, function (item) {
                var modelDef = {};
                modelDef.properties = {};
                modelDef.allProperties = {};
                result[item.name] = modelDef;
                var col_sql = "pragma table_info ('" + item.name + "');";
                var cols = self.db.all.sync(self.db, col_sql);
                _.forEach(cols, function (col) {
                    var prop = ReverseEngine.sqliteTypeToOrmType(col.type);
                    prop.indexed = col.pk !== 0;
                    prop.name = col.name;
                    prop.defaultValue = col.dflt_value;
                    prop.mapsTo = col.name;
                    prop.unique = col.pk !== 0;
                    // Set primary key
                    if (col.pk && col.pk !== 0) {
                        if (!modelDef.id)
                            modelDef.id = [];
                        modelDef.id[col.pk - 1] = col.name;
                    }
                    modelDef.properties[prop.name] = prop;
                    modelDef.allProperties[prop.name] = prop;
                });
                var indexList = self.db.all.sync(self.db, "pragma index_list ('" + item.name + "');");
                _.forEach(indexList, function (idxItem) {
                    var indexCols = self.db.all.sync(self.db, "pragma index_xinfo ('" + idxItem.name + "');");
                    _.forEach(indexCols, function (idxCol) {
                    });
                });
                var fk_sql = "pragma foreign_key_list ('" + item.name + "');";
                var fkeys = self.db.all.sync(self.db, fk_sql);
                _.forEach(fkeys, function (item) {
                    var oneAssoc = {};
                    oneAssoc.field = { name: { name: item.from } };
                    oneAssoc.name = item.table;
                    // Based on update and delete constraints, we can make wide
                    // guess about how deep relation is between 2 tables.
                    // For cascade delete we assume that referenced table belongs to
                    // the parent table
                    if (!modelDef.one_associations)
                        modelDef.one_associations = [];
                    modelDef.one_associations.push(oneAssoc);
                    // TODO Process many-to-many associations
                    var manyAssoc = {};
                });
            });
            return result;
        };
        return ReverseEngine;
    }());
    exports.ReverseEngine = ReverseEngine;
});
//# sourceMappingURL=reverseEng.js.map