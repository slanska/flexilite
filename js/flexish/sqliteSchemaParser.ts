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
     NVARCHAR(x), NVARCHAR

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
                let regx = /([^)]+)\(([^)]+)\)/;
                let matches = regx.exec(sqliteCol.type.toLowerCase());
                if (matches.length === 3) {
                    let size = Number(matches[2]);
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

type ClassDefCollection = {[name: string]: IClassDefinition};

/*
 Loads schema from SQLite database
 and parses it to Flexilite class definition
 Returns promise which resolves to dictionary of Flexilite classes
 */
export function parseSQLiteSchema(db: sqlite.Database): Promise<ClassDefCollection> {
    let outSchema: ClassDefCollection = {};
    let result: Promise<ClassDefCollection>;
    let colInfoArray = [];
    let idxInfoArray = [];
    let fkInfoArray = [];

    let tableNames: string[] = [];

    result = new Promise<ClassDefCollection>((resolve, reject) => {

        db.allAsync(
            `select * from sqlite_master where type = 'table' and name not like 'sqlite%';`)
            .then((tables: ISQLiteTableInfo[]) => {
                _.forEach(tables, (item: any) => {
                    colInfoArray.push(db.allAsync(`pragma table_info ('${item.name}');`));
                    idxInfoArray.push(db.allAsync(`pragma index_list ('${item.name}');`));
                    fkInfoArray.push(db.allAsync(`pragma foreign_key_list ('${item.name}');`));
                    tableNames.push(item.name);
                });

                return Promise.all([
                    Promise.each(colInfoArray, (cols: ISQLiteColumn[], idx: number) => {
                        let tblName = tableNames[idx];
                        let modelDef = {} as IClassDefinition;
                        modelDef.properties = {};

                        outSchema[tblName] = modelDef;

                        _.forEach(cols, (col: ISQLiteColumn) => {
                            let prop = sqliteTypeToFlexiType(col);

                            if (col.pk !== 0) {
                                prop.index = 'unique';
                            }

                            prop.defaultValue = col.dflt_value;

                            modelDef.properties[col.name] = prop;
                        });
                    }),
                    Promise.each(idxInfoArray, (indexList: ISQLiteIndexInfo[], ii: number) => {
                        _.forEach(indexList, (idxItem: ISQLiteIndexXInfo) => {
                            return db.allAsync(`pragma index_xinfo ('${idxItem.name}');`)
                                .then(indexCols => {
                                    _.forEach(indexCols, (idxCol: ISQLiteIndexColumn) => {

                                    });
                                });
                        });
                    })
                ]);
            })
            .then(() => {
                return resolve(outSchema);
            });
    });

    return result;
}
