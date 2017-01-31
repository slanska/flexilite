/**
 * Created by slanska on 2016-03-04.
 */
/// <reference path="../../typings/lib.d.ts" />
///<reference path="../typings/api.d.ts"/>
///<reference path="../typings/definitions.d.ts"/>
'use strict';
var _ = require('lodash');
var Promise = require('bluebird');
function sqliteTypeToFlexiType(sqliteCol) {
    var p = { rules: { type: 'text' } };
    if (!_.isNull(sqliteCol.type)) {
        switch (sqliteCol.type.toLowerCase()) {
            case 'text':
            case 'nvarchar':
            case 'varchar':
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
                    switch (matches[1]) {
                        case 'blob':
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
            _.forEach(tables, function (item) {
                colInfoArray.push(db.allAsync("pragma table_info ('" + item.name + "');"));
                idxInfoArray.push(db.allAsync("pragma index_list ('" + item.name + "');"));
                fkInfoArray.push(db.allAsync("pragma foreign_key_list ('" + item.name + "');"));
                tableNames.push(item.name);
            });
            return Promise.all([
                Promise.each(colInfoArray, function (cols, idx) {
                    var tblName = tableNames[idx];
                    var modelDef = {};
                    modelDef.properties = {};
                    outSchema[tblName] = modelDef;
                    _.forEach(cols, function (col) {
                        var prop = sqliteTypeToFlexiType(col);
                        if (col.pk !== 0) {
                            prop.index = 'unique';
                        }
                        prop.defaultValue = col.dflt_value;
                        modelDef.properties[col.name] = prop;
                    });
                }),
                Promise.each(idxInfoArray, function (indexList, ii) {
                    _.forEach(indexList, function (idxItem) {
                        return db.allAsync("pragma index_xinfo ('" + idxItem.name + "');")
                            .then(function (indexCols) {
                            _.forEach(indexCols, function (idxCol) {
                            });
                        });
                    });
                })
            ]);
        })
            .then(function () {
            return resolve(outSchema);
        });
    });
    return result;
}
exports.parseSQLiteSchema = parseSQLiteSchema;
//# sourceMappingURL=sqliteSchemaParser.js.map