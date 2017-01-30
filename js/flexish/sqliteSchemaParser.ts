/**
 * Created by slanska on 2016-03-04.
 */

/// <reference path="../../typings/lib.d.ts" />
///<reference path="../typings/api.d.ts"/>


'use strict';

import sqlite = require('sqlite3');
import _ = require('lodash');
import Promise = require('bluebird');

Promise.promisify(sqlite.Database.prototype.all);
Promise.promisify(sqlite.Database.prototype.exec);
Promise.promisify(sqlite.Database.prototype.run);

/*
 Contracts to SQLite system objects
 */
interface ISQLiteColumn {
    cid: number;
    name: string;

    /*
     The following values might be returned by SQLite:
     INTEGER
     NUMERIC
     TEXT(x), TEXT
     BLOB(x), BLOB
     DATETIME
     BOOL
     JSON1

     <null> -> any
     */
    type: string;
    notnull: number;
    dflt_value: any;

    /*
     Position in primary key, starting from 1, or 0, if column
     is not a part of primary key
     */
    pk: number;
}

interface ISQLiteIndexInfo {
    seq: number;
    cid: number;
    name: string;
}

/*
 Row structure of pragma table_info <TableName>
 */
interface ISQLiteTableInfo {
    name: string;
    type: string
    tbl_name: string;
    root_page: number;
}

/*
 pragma index_xinfo
 */
interface ISQLiteIndexXInfo extends ISQLiteIndexInfo {
    unique: number | boolean;
    origin: string;
    partial: number | boolean;
}

/*
 pragma index_list
 */
interface ISQLiteIndexColumn {
    seq: number;
    cid: number;
    name: string;
    desc: number;
    coll: string;
    key: number | boolean;
}

/*
 Contract for foreign key information as returned by SQLite
 PRAGMA foreign_key_list('table_name')
 */
interface ISQLiteForeignKeyInfo {
    /*
     Sequential number
     */
    seq: number;

    /*
     Name of referenced table
     */
    table: string;

    /*
     Name of column(s) in the source table
     */
    from: string;

    /*
     Name of column(s) in the referenced table
     */
    to: string;

    /*
     There are following values expected for these 2 fields:
     NONE
     NO_ACTION - loose relation
     CASCADE - parentship
     RESTRICT - "partnership"
     SET_NULL
     SET_DEFAULT

     */
    on_update: string;
    on_delete: string;

    /*
     Possible values:
     MATCH
     ???
     */
    match: string;
}


function sqliteTypeToOrmType(type: string): {type: string, size?: number, time?: boolean} {
    if (_.isNull(type))
        return {type: 'text'};

    switch (type.toLowerCase()) {
        case 'text':
            return {type: 'text'};
        case 'numeric':
        case 'real':
            return {type: 'number'};
        case 'bool':
            return {type: 'boolean'};
        case 'json1':
            return {type: 'object'};
        case 'date':
            return {type: 'date', time: false};
        case 'datetime':
            return {type: 'date', time: true};
        case 'blob':
            return {type: 'binary'};
        case 'integer':
            return {type: 'integer'};
        default:
            let regx = /([^)]+)\(([^)]+)\)/;
            let matches = regx.exec(type.toLowerCase());
            if (matches.length === 3) {
                if (matches[1] === 'blob')
                    return {type: 'binary', size: Number(matches[2])};

                if (matches[1] === 'numeric') {
                    return {type: 'number'};
                }

                return {type: 'text', size: Number(matches[2])};
            }
            return {type: 'text'};
    }
}

/*
 Loads schema from SQLite database
 and parses it to Flexilite class definition
 Returns promise which resolves to dictionary of Flexilite classes
 */
export function parseSQLiteSchema(db: sqlite.Database, outSchema: {[name: string]: any}) {
    outSchema = {} as any;

    let tables = db.all(
        `select * from sqlite_master where type = 'table' and name not like 'sqlite%';`);

    _.forEach(tables, (item: any) => {
        var modelDef = {} as any; //
        modelDef.properties = {};
        modelDef.allProperties = {};

        outSchema[item.name] = modelDef;

        let col_sql = `pragma table_info ('${item.name}');`;
        db.allAsync(col_sql).then((cols: ISQLiteColumn[]) => {
            _.forEach(cols, (col: ISQLiteColumn) => {
                var prop = sqliteTypeToOrmType(col.type) as any; //
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
            return db.allAsync(`pragma index_list ('${item.name}');`);
        })
            .then(indexList => {
                _.forEach(indexList, (idxItem: ISQLiteIndexXInfo) => {
                    var indexCols = db.allAsync(`pragma index_xinfo ('${idxItem.name}');`);
                    _.forEach(indexCols, (idxCol: ISQLiteIndexColumn) => {

                    });
                });

                let fk_sql = `pragma foreign_key_list ('${item.name}');`;
                return db.all(fk_sql);
            })
            .then(fkeys => {
                _.forEach(fkeys, (item: ISQLiteForeignKeyInfo) => {
                    var oneAssoc = {} as any; //
                    oneAssoc.field = {name: {name: item.from}};
                    oneAssoc.name = item.table;

                    // Based on update and delete constraints, we can make wide
                    // guess about how deep relation is between 2 tables.
                    // For cascade delete we assume that referenced table belongs to
                    // the parent table

                    if (!modelDef.one_associations)
                        modelDef.one_associations = [];
                    modelDef.one_associations.push(oneAssoc);

                    // TODO Process many-to-many associations
                    var manyAssoc = {} as any; //


                });

            });
    });

    return outSchema;
}






