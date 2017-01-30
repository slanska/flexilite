/**
 * Created by slanska on 2016-03-04.
 */
/// <reference path="../../typings/lib.d.ts" />
///<reference path="../typings/api.d.ts"/>
'use strict';
var sqlite = require('sqlite3');
var _ = require('lodash');
var Promise = require('bluebird');
Promise.promisify(sqlite.Database.prototype.all);
Promise.promisify(sqlite.Database.prototype.exec);
Promise.promisify(sqlite.Database.prototype.run);
function sqliteTypeToOrmType(type) {
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
}
/*
 Loads schema from SQLite database
 and parses it to Flexilite class definition
 Returns promise which resolves to dictionary of Flexilite classes
 */
function parseSQLiteSchema(db, outSchema) {
    outSchema = {};
    var tables = db.all("select * from sqlite_master where type = 'table' and name not like 'sqlite%';");
    _.forEach(tables, function (item) {
        var modelDef = {}; //
        modelDef.properties = {};
        modelDef.allProperties = {};
        outSchema[item.name] = modelDef;
        var col_sql = "pragma table_info ('" + item.name + "');";
        db.allAsync(col_sql).then(function (cols) {
            _.forEach(cols, function (col) {
                var prop = sqliteTypeToOrmType(col.type); //
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
                if (!modelDef.one_associations)
                    modelDef.one_associations = [];
                modelDef.one_associations.push(oneAssoc);
                // TODO Process many-to-many associations
                var manyAssoc = {}; //
            });
        });
    });
    return outSchema;
}
exports.parseSQLiteSchema = parseSQLiteSchema;
//# sourceMappingURL=sqliteSchemaParser.js.map