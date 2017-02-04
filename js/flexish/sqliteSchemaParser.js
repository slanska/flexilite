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
    var SQLiteSchemaParser = (function () {
        function SQLiteSchemaParser(db) {
            this.db = db;
            this.outSchema = {};
            this.tableInfo = [];
            this.results = [];
        }
        SQLiteSchemaParser.prototype.sqliteColToFlexiProp = function (sqliteCol) {
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
        };
        /*
         Iterates over list of tables and tries to find candidates for many-to-many relation tables.
         Canonical conditions:
         1) table should have only 2 columns (A & B)
         2) table should have primary index on both columns (A and B)
         3) Both columns are foreign keys to some tables
         4) there is an index on column B (optional, not required)
    
         If conditions 1-4 are met, this table is considered as a many-to-many list.
         Foreign key info in SQLite comes from detail/linked table, so it is either N:1 or 1:1
    
         */
        SQLiteSchemaParser.prototype.processMany2ManyRelations = function () {
            // Find tables with 2 columns
            // Check if conditions 2 and 3 are met
            // If so, create 2 relational properties
            /*
             Their names would be based on the following rules:
             Assume that there are tables A and B, with ID columns a and b.
             As and Bs are pluralized form of table names
             Properties will be named: As, or As_a (if As already used) and Bs or Bs_b, respectively
    
             */
            var self = this;
            _.forEach(self.tableInfo, function (it) {
                if (it.columnCount === 2) {
                }
            });
        };
        SQLiteSchemaParser.prototype.findTableInfoByName = function (tableName) {
            return _.find(this.tableInfo, function (ti) {
                return ti.table === tableName;
            });
        };
        SQLiteSchemaParser.prototype.createReferenceProperties = function () {
            /*
             reference property
             */
            // let refProp = {rules: {type: 'reference'}} as IClassPropertyDef;
            // refProp.refDef = {
            //     $className: fk.table,
            //     relationRule: 'no_action',
            //
            // };
            // Check if we have tables which are used for many-to-many relation
        };
        /*
         Loads schema from SQLite database
         and parses it to Flexilite class definition
         Returns promise which resolves to dictionary of Flexilite classes
         */
        SQLiteSchemaParser.prototype.parseSchema = function () {
            var self = this;
            self.outSchema = {};
            var result;
            var colInfoArray = [];
            var idxInfoArray = [];
            var fkInfoArray = [];
            self.tableInfo = [];
            result = new Promise(function (resolve, reject) {
                self.db.allAsync("select * from sqlite_master where type = 'table' and name not like 'sqlite%';")
                    .then(function (tables) {
                    // On this step prepare class definition and create promises for requests on individual tables
                    _.forEach(tables, function (item) {
                        // Init resulting dictionary
                        self.outSchema[item.name] = {
                            properties: {},
                            specialProperties: {}
                        };
                        colInfoArray.push(self.db.allAsync("pragma table_info ('" + item.name + "');"));
                        idxInfoArray.push(self.db.allAsync("pragma index_list ('" + item.name + "');"));
                        fkInfoArray.push(self.db.allAsync("pragma foreign_key_list ('" + item.name + "');"));
                        self.tableInfo.push({
                            table: item.name,
                            columnCount: 0,
                            columns: {},
                            inFKeys: [],
                            outFKeys: [],
                            manyToManyTable: false
                        });
                    });
                    return Promise.each(colInfoArray, function (cols, idx) {
                        var tblMap = self.tableInfo[idx];
                        var modelDef = self.outSchema[tblMap.table];
                        _.forEach(cols, function (col) {
                            var prop = self.sqliteColToFlexiProp(col);
                            prop.rules.maxOccurences = 1;
                            prop.rules.minOccurences = Number(col.notnull);
                            if (col.pk !== 0) {
                                // Handle multiple column PKEY
                                prop.index = 'unique';
                            }
                            prop.defaultValue = col.dflt_value;
                            modelDef.properties[col.name] = prop;
                            tblMap.columns[col.cid] = col;
                            tblMap.columnCount++;
                        });
                    });
                })
                    .then(function () {
                    return Promise.each(idxInfoArray, function (indexList, idx) {
                        var tbl = self.tableInfo[idx];
                        _.forEach(indexList, function (idxItem) {
                            return self.db.allAsync("pragma index_xinfo ('" + idxItem.name + "');")
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
                            var tbl_1 = self.tableInfo[idx];
                            _.forEach(fkInfo, function (fk, idx) {
                                fk.srcTable = tbl_1.table;
                                tbl_1.outFKeys.push(fk);
                                var outTbl = self.findTableInfoByName(fk.table);
                                if (!outTbl) {
                                    self.results.push({
                                        type: 'error',
                                        message: "Table specified in FKEY not found", tableName: fk.table
                                    });
                                    return;
                                }
                                outTbl.inFKeys.push(fk);
                            });
                        }
                    });
                })
                    .then(function () {
                    /*
                     First process all candidates for many-to-many relations.
                     After this step, some tables and foreign key specs may be removed from internal tblInfo list
                     */
                    self.processMany2ManyRelations();
                    /*
                     Second, processing what has left and create reference properties
                     Reference property gets name based on name of references table
                     and, optionally, 'from' column, so for relation between Order->OrderDetails by OrderID
                     (for both tables) 2 properties will be created:
                     a) in Orders: OrderDetails
                     b) in OrderDetails: Order (singular form of Orders)
                     In case of name conflict, ref property gets fully qualified name:
                     Order_OrderID, OrderDetails_OrderID
                     */
                    self.createReferenceProperties();
                    return resolve(self.outSchema);
                });
            });
            return result;
        };
        return SQLiteSchemaParser;
    }());
    exports.SQLiteSchemaParser = SQLiteSchemaParser;
});
//# sourceMappingURL=sqliteSchemaParser.js.map