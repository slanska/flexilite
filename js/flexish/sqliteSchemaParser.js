/**
 * Created by slanska on 2016-03-04.
 */
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports", 'sqlite3', 'lodash', 'bluebird'], factory);
    }
})(function (require, exports) {
    /// <reference path="../../typings/lib.d.ts" />
    ///<reference path="../typings/api.d.ts"/>
    ///<reference path="../typings/definitions.d.ts"/>
    'use strict';
    var sqlite = require('sqlite3');
    var _ = require('lodash');
    var Promise = require('bluebird');
    Promise.promisify(sqlite.Database.prototype.all);
    Promise.promisify(sqlite.Database.prototype.exec);
    Promise.promisify(sqlite.Database.prototype.run);
    function sqliteTypeToFlexiType(sqliteCol) {
        var p = { rules: { type: 'text' } };
        if (!_.isNull(sqliteCol.type)) {
            switch (sqliteCol.type.toLowerCase()) {
                case 'text':
                    p.rules.type = 'text';
                    break;
                case 'numeric':
                case 'real':
                    p.rules.type = 'number';
                    break;
                case 'bool':
                    p.rules.type = 'boolean';
                    break;
                case 'json1':
                    p.rules.type = 'json';
                    break;
                case 'date':
                    p.rules.type = 'date';
                    break;
                case 'datetime':
                    p.rules.type = 'datetime';
                    break;
                case 'blob':
                    p.rules.type = 'binary';
                    break;
                case 'integer':
                    p.rules.type = 'integer';
                    break;
                default:
                    var regx = /([^)]+)\(([^)]+)\)/;
                    var matches = regx.exec(sqliteCol.type.toLowerCase());
                    if (matches.length === 3) {
                        var size = Number(matches[2]);
                        if (matches[1] === 'blob') {
                            if (sqliteCol.notnull === 1 && size === 16)
                                p.rules.type = 'uuid';
                            else {
                                p.rules.type = 'binary';
                                p.rules.maxLength = size;
                            }
                        }
                        if (matches[1] === 'numeric') {
                            // TODO Process size for numeric?
                            p.rules.type = 'number';
                        }
                    }
            }
        }
        return p;
    }
    /*
     Loads schema from SQLite database
     and parses it to Flexilite class definition
     Returns promise which resolves to dictionary of Flexilite classes
     */
    function parseSQLiteSchema(db, outSchema) {
        outSchema = {};
        return new Promise(function (resolve, reject) {
            var tables = db.all("select * from sqlite_master where type = 'table' and name not like 'sqlite%';");
            _.forEach(tables, function (item) {
                var modelDef = {};
                modelDef.properties = {};
                outSchema[item.name] = modelDef;
                var col_sql = "pragma table_info ('" + item.name + "');";
                db.allAsync(col_sql).then(function (cols) {
                    _.forEach(cols, function (col) {
                        var prop = sqliteTypeToFlexiType(col);
                        if (col.pk !== 0) {
                            prop.index = 'unique';
                        }
                        prop.defaultValue = col.dflt_value;
                        // Set primary key
                        // if (col.pk && col.pk !== 0) {
                        //     if (!modelDef.id)
                        //         modelDef.id = [];
                        //     modelDef.id[col.pk - 1] = col.name;
                        // }
                        modelDef.properties[col.name] = prop;
                    });
                    return db.allAsync("pragma index_list ('" + item.name + "');");
                })
                    .then(function (indexList) {
                    _.forEach(indexList, function (idxItem) {
                        var indexCols = db.allAsync("pragma index_xinfo ('" + idxItem.name + "');");
                        _.forEach(indexCols, function (idxCol) {
                        });
                    });
                    var fk_sql = "pragma foreign_key_list ('" + item.name + "');";
                    return db.all(fk_sql);
                })
                    .then(function (fkeys) {
                    _.forEach(fkeys, function (item) {
                        var oneAssoc = {}; //
                        oneAssoc.field = { name: { name: item.from } };
                        oneAssoc.name = item.table;
                        // Based on update and delete constraints, we can make wide
                        // guess about how deep relation is between 2 tables.
                        // For cascade delete we assume that referenced table belongs to
                        // the parent table
                    });
                });
            });
            return outSchema;
        });
    }
    exports.parseSQLiteSchema = parseSQLiteSchema;
});
//# sourceMappingURL=sqliteSchemaParser.js.map