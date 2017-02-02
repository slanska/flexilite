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
import Dictionary = _.Dictionary;
var Pluralize = require('pluralize');

/*
 Contracts to SQLite system objects
 */
interface ISQLiteColumn {
    cid: number;
    name: string;

    /*
     This is the list of SQLite column types and their mapping to
     Flexilite property types and other attributes:
     INTEGER
     SMALLINT -> minValue is set to -32768, maxValue +32767
     TINYINT -> minValue is set to 0, maxValue +255

     MONEY -> Basic format is used. Money values are stored as integers,
     with 4 decimal signs. Float and integer values are accepted

     NUMERIC -> number
     FLOAT
     REAL

     TEXT(x), TEXT -> text. If (x) is specified, it used for maxLength attribute
     NVARCHAR(x), NVARCHAR
     VARCHAR(x), VARCHAR
     NCHAR(x), NCHAR

     BLOB(x), BLOB -> blob
     BINARY(x), BINARY
     VARBINARY(x), VARBINARY

     MEMO -> text
     JSON1

     DATETIME -> stored as float, in Julian days
     DATE
     TIME

     BOOL -> bool
     BIT

     <null> or <other> -> any
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
    /*
     position in index (for multi column indexes)
     */
    seq: number;

    /*
     column number
     */
    cid: number;

    /*
     index name
     */
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

    /*
     Column ID as number
     */
    cid: number;

    /*
     Index name
     */
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

function sqliteColToFlexiProp(sqliteCol: ISQLiteColumn): IClassPropertyDef {
    let p = {rules: {type: 'any'} as IPropertyRulesSettings} as IClassPropertyDef;

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
                let regx = /([^)]+)\(([^)]+)\)/;
                let matches = regx.exec(sqliteCol.type.toLowerCase());
                if (matches && matches.length === 3) {
                    let size = Number(matches[2]);
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

type ClassDefCollection = {[name: string]: IClassDefinition};

/*
 Internally used declaration. Has table name and mapping between column numbers and column names
 */
interface ISQLiteColumnMapping {
    /*
     Table name
     */
    table: string;

    /*
     Column info mapping by column ID (number)
     */
    columns: {[cid: number]: ISQLiteColumn};
}

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

    let tableNames: ISQLiteColumnMapping[] = [];

    result = new Promise<ClassDefCollection>((resolve, reject) => {

        db.allAsync(
            `select * from sqlite_master where type = 'table' and name not like 'sqlite%';`)
            .then((tables: ISQLiteTableInfo[]) => {
                // On this step prepare class definition and create promises for requests on individual tables
                _.forEach(tables, (item: ISQLiteTableInfo) => {

                    // Init resulting dictionary
                    outSchema[item.name] = {
                        properties: {},
                        specialProperties: {}
                    } as IClassDefinition;

                    colInfoArray.push(db.allAsync(`pragma table_info ('${item.name}');`));
                    idxInfoArray.push(db.allAsync(`pragma index_list ('${item.name}');`));
                    fkInfoArray.push(db.allAsync(`pragma foreign_key_list ('${item.name}');`));
                    tableNames.push({table: item.name, columns: {}});
                });

                return Promise.each(colInfoArray, (cols: ISQLiteColumn[], idx: number) => {
                    let tblMap = tableNames[idx];
                    let modelDef = outSchema[tblMap.table];

                    _.forEach(cols, (col: ISQLiteColumn) => {
                        let prop = sqliteColToFlexiProp(col);

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
            .then(() => {
                return Promise.each(idxInfoArray, (indexList: ISQLiteIndexInfo[], idx: number) => {
                    let tbl = tableNames[idx];
                    _.forEach(indexList, (idxItem: ISQLiteIndexXInfo) => {
                        return db.allAsync(`pragma index_xinfo ('${idxItem.name}');`)
                            .then(indexCols => {
                                _.forEach(indexCols, (idxCol: ISQLiteIndexColumn) => {

                                });
                            });
                    });
                });
            })
            .then(() => {
                return Promise.each(fkInfoArray, (fkInfo: ISQLiteForeignKeyInfo[], idx: number) => {
                    if (fkInfo.length > 0) {
                        let tbl = tableNames[idx];

                        _.forEach(fkInfo, (fk: ISQLiteForeignKeyInfo, idx: number) => {
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
                            let prop2 = {
                                rules: {type: 'reference'},
                                refDef: {
                                    $className: fk.table,
                                    relationRule: fk.on_delete
                                }
                            } as IClassPropertyDef;


                            // Check if we have tables which are used for many-to-many relation

                        });
                    }
                });
            })
            .then(() => {
                return resolve(outSchema);
            });
    });

    return result;
}
