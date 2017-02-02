/**
 * Created by slanska on 2016-03-04.
 */
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports", 'lodash', 'bluebird'], factory);
    }
})(function (require, exports) {
    /// <reference path="../../typings/lib.d.ts" />
    ///<reference path="../typings/api.d.ts"/>
    ///<reference path="../typings/definitions.d.ts"/>
    'use strict';
    var _ = require('lodash');
    var Promise = require('bluebird');
    var Pluralize = require('pluralize');
    function sqliteColToFlexiProp(sqliteCol) {
        var p = { rules: { type: 'any' } };
        if (!_.isNull(sqliteCol.type)) {
            switch (sqliteCol.type.toLowerCase()) {
                case 'text':
                case 'nvarchar':
                case 'varchar':
                case 'nchar':
                case 'memo':
                    p.rules.type = 'text';
                    break;
                case 'money':
                    p.rules.type = 'money';
                    break;
                case 'numeric':
                case 'real':
                case 'float':
                    p.rules.type = 'number';
                    break;
                case 'bool':
                case 'bit':
                    p.rules.type = 'boolean';
                    break;
                case 'json1':
                    p.rules.type = 'json';
                    break;
                case 'date':
                    p.rules.type = 'date';
                    break;
                case 'time':
                    p.rules.type = 'timespan';
                    break;
                case 'datetime':
                    p.rules.type = 'datetime';
                    break;
                case 'blob':
                case 'binary':
                case 'varbinary':
                    p.rules.type = 'binary';
                    break;
                case 'integer':
                    p.rules.type = 'integer';
                    break;
                case 'smallint':
                    p.rules.type = 'integer';
                    p.rules.minValue = -32768;
                    p.rules.maxValue = 32767;
                    break;
                case 'tinyint':
                    p.rules.type = 'integer';
                    p.rules.minValue = 0;
                    p.rules.maxValue = 255;
                    break;
                default:
                    var regx = /([^)]+)\(([^)]+)\)/;
                    var matches = regx.exec(sqliteCol.type.toLowerCase());
                    if (matches && matches.length === 3) {
                        var size = Number(matches[2]);
                        switch (matches[1]) {
                            case 'blob':
                            case 'binary':
                            case 'varbinary':
                                if (sqliteCol.notnull === 1 && size === 16)
                                    p.rules.type = 'uuid';
                                else {
                                    p.rules.type = 'binary';
                                    p.rules.maxLength = size;
                                }
                                break;
                            case 'numeric':
                                // TODO Process size for numeric?
                                p.rules.type = 'number';
                                break;
                            case 'nchar':
                            case 'nvarchar':
                            case 'varchar':
                            case 'text':
                                p.rules.type = 'text';
                                p.rules.maxLength = size;
                                break;
                        }
                    }
            }
        }
        return p;
    }
    /*
     Determine if this is many-to-many relationship
     Conditions:
     1) table should have only 2 columns (A & B)
     2) table should have primary index on both columns (A and B)
     3) Both columns are foreign keys to some tables
     4) there might be index on column B (optional, not required)
    
     If conditions 1-3 are met, this table is considered as a many-to-many list.
     Classes for both referencing tables will have reference properties, named
     */
    function checkIfManyToMany() {
    }
    /*
     Loads schema from SQLite database
     and parses it to Flexilite class definition
     Returns promise which resolves to dictionary of Flexilite classes
     */
    function parseSQLiteSchema(db) {
        var outSchema = {};
        var result;
        var colInfoArray = [];
        var idxInfoArray = [];
        var fkInfoArray = [];
        var tableNames = [];
        result = new Promise(function (resolve, reject) {
            db.allAsync("select * from sqlite_master where type = 'table' and name not like 'sqlite%';")
                .then(function (tables) {
                // On this step prepare class definition and create promises for requests on individual tables
                _.forEach(tables, function (item) {
                    // Init resulting dictionary
                    outSchema[item.name] = {
                        properties: {},
                        specialProperties: {}
                    };
                    colInfoArray.push(db.allAsync("pragma table_info ('" + item.name + "');"));
                    idxInfoArray.push(db.allAsync("pragma index_list ('" + item.name + "');"));
                    fkInfoArray.push(db.allAsync("pragma foreign_key_list ('" + item.name + "');"));
                    tableNames.push({ table: item.name, columns: {} });
                });
                return Promise.each(colInfoArray, function (cols, idx) {
                    var tblMap = tableNames[idx];
                    var modelDef = outSchema[tblMap.table];
                    _.forEach(cols, function (col) {
                        var prop = sqliteColToFlexiProp(col);
                        prop.rules.maxOccurences = 1;
                        prop.rules.minOccurences = Number(col.notnull);
                        if (col.pk !== 0) {
                            // Handle multiple column PKEY
                            prop.index = 'unique';
                        }
                        prop.defaultValue = col.dflt_value;
                        modelDef.properties[col.name] = prop;
                        tblMap.columns[col.cid] = col;
                    });
                });
            })
                .then(function () {
                return Promise.each(idxInfoArray, function (indexList, idx) {
                    var tbl = tableNames[idx];
                    _.forEach(indexList, function (idxItem) {
                        return db.allAsync("pragma index_xinfo ('" + idxItem.name + "');")
                            .then(function (indexCols) {
                            _.forEach(indexCols, function (idxCol) {
                            });
                        });
                    });
                });
            })
                .then(function () {
                return Promise.each(fkInfoArray, function (fkInfo, idx) {
                    if (fkInfo.length > 0) {
                        var tbl = tableNames[idx];
                        _.forEach(fkInfo, function (fk, idx) {
                            /*
                             Create relations based on foreign key definition
                             Reference property gets name based on name of references table
                             and, optionally, 'from' column, so for relation between Order->OrderDetails by OrderID
                             (for both tables) 2 properties will be created:
                             a) in Orders: OrderDetails
                             b) in OrderDetails: Order (singular form of Orders)
                             In case of name conflict, ref property gets fully qualified name:
                             Order_OrderID, OrderDetails_OrderID

                             */
                            /*
                             1st prop: master to linked
                             */
                            /*
                             2nd prop: linked to master
                             */
                            var prop2 = {
                                rules: { type: 'reference' },
                                refDef: {
                                    $className: fk.table,
                                    relationRule: fk.on_delete
                                }
                            };
                            // Check if we have tables which are used for many-to-many relation
                        });
                    }
                });
            })
                .then(function () {
                return resolve(outSchema);
            });
        });
        return result;
    }
    exports.parseSQLiteSchema = parseSQLiteSchema;
});
//# sourceMappingURL=sqliteSchemaParser.js.map