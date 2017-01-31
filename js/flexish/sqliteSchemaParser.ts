/**
 * Created by slanska on 2016-03-04.
 */

/// <reference path="../../typings/lib.d.ts" />
///<reference path="../typings/api.d.ts"/>
///<reference path="../typings/definitions.d.ts"/>

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

    /*
     0 - if not required
     1 - if required
     */
    notnull: number;

    /*
     Default value
     */
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


function sqliteTypeToFlexiType(sqliteCol: ISQLiteColumn): IClassPropertyDef {
    let p = {rules: {type: 'text'} as IPropertyRulesSettings} as IClassPropertyDef;

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
                let regx = /([^)]+)\(([^)]+)\)/;
                let matches = regx.exec(sqliteCol.type.toLowerCase());
                if (matches.length === 3) {
                    let size = Number(matches[2]);
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
export function parseSQLiteSchema(db: sqlite.Database, outSchema: {[name: string]: any}) {
    outSchema = {} as any;

    return new Promise((resolve, reject) => {

        let tables = db.all(
            `select * from sqlite_master where type = 'table' and name not like 'sqlite%';`);

        _.forEach(tables, (item: any) => {
            let modelDef = {} as IClassDefinition;
            modelDef.properties = {};

            outSchema[item.name] = modelDef;

            let col_sql = `pragma table_info ('${item.name}');`;
            db.allAsync(col_sql).then((cols: ISQLiteColumn[]) => {
                _.forEach(cols, (col: ISQLiteColumn) => {
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

                return db.allAsync(`pragma index_list ('${item.name}');`);
            })
                .then(indexList => {
                    _.forEach(indexList, (idxItem: ISQLiteIndexXInfo) => {
                        let indexCols = db.allAsync(`pragma index_xinfo ('${idxItem.name}');`);
                        _.forEach(indexCols, (idxCol: ISQLiteIndexColumn) => {

                        });
                    });

                    let fk_sql = `pragma foreign_key_list ('${item.name}');`;
                    return db.all(fk_sql);
                })
                .then(fkeys => {
                    _.forEach(fkeys, (item: ISQLiteForeignKeyInfo) => {
                        let oneAssoc = {} as any; //
                        oneAssoc.field = {name: {name: item.from}};
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