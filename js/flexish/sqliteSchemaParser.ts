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
let Pluralize = require('pluralize');

sqlite.Database.prototype['allAsync'] = Promise.promisify(sqlite.Database.prototype.all) as any;
sqlite.Database.prototype['execAsync'] = Promise.promisify(sqlite.Database.prototype.exec) as any;
sqlite.Database.prototype['runAsync'] = Promise.promisify(sqlite.Database.prototype.run)as any;

/*
 Contracts to SQLite system objects
 Row structure of pragma table_info(<TableName>)
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

    /*
     Additional attribute with index column data
     */
    columns?: ISQLiteIndexColumn[];
}

/*

 */
interface ISQLiteTableInfo {
    name: string;
    type: string
    tbl_name: string;
    root_page: number;
}

// /*
//  pragma index_xinfo
//  */
// interface ISQLiteIndexXInfo extends ISQLiteIndexInfo {
//     unique: number | boolean;
//     origin: string;
//     partial: number | boolean;
// }

/*
 pragma index_info
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
}

/*
 Contract for foreign key information as returned by SQLite
 PRAGMA foreign_key_list('table_name')

 In addition to columns coming from PRAGMA this object has additional column to track source table
 */
interface ISQLiteForeignKeyInfo {
    /*
     Foreign key sequential number
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

    srcTable?: string;
}


type ClassDefCollection = {[name: string]: IClassDefinition};

/*
 Internally used object with table name, mapping between column numbers and column names and other attributes
 */
interface ITableInfo {
    /*
     Table name
     */
    table: string;

    columnCount: number;

    /*
     Column info mapping by column ID (number)
     */
    columns: {[cid: number]: ISQLiteColumn};

    /*
     All foreign key definitions which point to this table
     */
    inFKeys: ISQLiteForeignKeyInfo[];

    /*

     */
    outFKeys: ISQLiteForeignKeyInfo[];

    /*
     Set to true if table was found as many-to-many association
     */
    manyToManyTable: boolean;

    indexes?: ISQLiteIndexInfo[];
}

export interface IFlexishResultItem {
    type: 'error' | 'warn' | 'info';
    message: string;
    tableName: string;
}

export type FlexishResults = IFlexishResultItem[];

export class SQLiteSchemaParser {

    public outSchema: ClassDefCollection = {};
    public tableInfo: ITableInfo[] = [];
    public results: FlexishResults = [];

    constructor(protected db: sqlite.Database) {
    }

    private sqliteColToFlexiProp(sqliteCol: ISQLiteColumn): IClassPropertyDef {
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
     Iterates over list of tables and tries to find candidates for many-to-many relation tables.
     Canonical conditions:
     1) table should have only 2 columns (A & B)
     2) table should have primary index on both columns (A and B)
     3) Both columns are foreign keys to some tables
     4) there is an index on column B (optional, not required)

     If conditions 1-4 are met, this table is considered as a many-to-many list.
     Foreign key info in SQLite comes from detail/linked table, so it is either N:1 or 1:1

     */
    private processMany2ManyRelations() {
        // Find tables with 2 columns
        // Check if conditions 2 and 3 are met
        // If so, create 2 relational properties
        /*
         Their names would be based on the following rules:
         Assume that there are tables A and B, with ID columns a and b.
         As and Bs are pluralized form of table names
         Properties will be named: As, or As_a (if As already used) and Bs or Bs_b, respectively

         */
        let self = this;
        _.forEach(self.tableInfo, (it) => {
            if (it.columnCount === 2) {

            }
        });

    }

    private findTableInfoByName(tableName: string): ITableInfo {
        return _.find(this.tableInfo, (ti: ITableInfo) => {
            return ti.table === tableName;
        });
    }

    /*
     Creates reference properties based on foreign key information
     If FKEY is from primary key, relation 1:1 is assumed (extending class)
     Otherwise, 1:N relation is assumed
     */
    private processReferenceProperties() {
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

    }

    /*
     Processes indexes specification using following rules:
     1) primary and unique indexes on single columns are processed as is
     2) unique indexes as well as partial indexes are not supported. Warning will be generated
     TODO: create composite computed properties
     3) DESC clause in index definition is ignored. Warning will be generated.
     4) non-unique indexes on text columns are converted to FTS indexes
     5) all numeric and datetime columns included into non-unique indexes (both single and multi column)
     are considered to participate in RTree index. Maximum 5 columns can be RTree-indexed. Priority is given
     6) Columns from non-unique indexes that were not included into FTS nor RTree indexes will be indexed. Note:
     for multi-column indexes only first columns in index definitions will be processed.
     7) All columns from non-unique indexes that were not included into FTS, RTree or regular indexes will NOT be indexed
     Warning be generated
     */
    private processIndexes() {
        let self = this;
        _.forEach(self.tableInfo, (ti) => {
            // ti.indexes.
        });

    }

    /*
     Determines which columns should be skipped during schema generation
     */
    private processColumns() {
    }

    /*
     Applies some guessing about role of columns based on their indexing and naming
     The following rules are applied:
     1) primary not autoincrement or unique non-text column gets role "uid"
     2) unique text column(s) get roles "code" and "name".
     3) If unique column name ends with '*Code'
     or its max length is shortest among other unique text columns, it gets role "code"
     4) If unique column name ends with "*Name", it gets role "name",
     */
    private processPropertyRoles() {

    }

    /*
     Loads schema from SQLite database
     and parses it to Flexilite class definition
     Returns promise which resolves to dictionary of Flexilite classes
     */
    public parseSchema(): Promise<ClassDefCollection> {
        let self = this;
        self.outSchema = {};
        let result: Promise<ClassDefCollection>;
        let colInfoArray = [];
        let idxInfoArray = [];
        let fkInfoArray = [];

        self.tableInfo = [];

        result = new Promise<ClassDefCollection>((resolve, reject) => {

            // Get list of tables (excluding internal tables)
            self.db.allAsync(
                `select * from sqlite_master where type = 'table' and name not like 'sqlite%';`)
                .then((tables: ISQLiteTableInfo[]) => {
                    // On this step prepare class definition and create promises for requests on individual tables
                    _.forEach(tables, (item: ISQLiteTableInfo) => {

                        // Init resulting dictionary
                        self.outSchema[item.name] = {
                            properties: {},
                            specialProperties: {}
                        } as IClassDefinition;

                        colInfoArray.push(self.db.allAsync(`pragma table_info ('${item.name}');`));
                        idxInfoArray.push(self.db.allAsync(`pragma index_list ('${item.name}');`));
                        fkInfoArray.push(self.db.allAsync(`pragma foreign_key_list ('${item.name}');`));
                        self.tableInfo.push({
                            table: item.name,
                            columnCount: 0,
                            columns: {},
                            inFKeys: [],
                            outFKeys: [],
                            manyToManyTable: false
                        });
                    });

                    return Promise.each(colInfoArray, (cols: ISQLiteColumn[], idx: number) => {
                        // Process columns
                        let tblMap = self.tableInfo[idx];
                        let modelDef = self.outSchema[tblMap.table];

                        _.forEach(cols, (col: ISQLiteColumn) => {
                            let prop = self.sqliteColToFlexiProp(col);

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

                .then(() => {
                    // Populate indexes
                    return Promise.each(idxInfoArray, (indexList: ISQLiteIndexInfo[], idx: number) => {
                        let tbl = self.tableInfo[idx];
                        _.forEach(indexList, (idxItem: ISQLiteIndexInfo) => {
                            return self.db.allAsync(`pragma index_info ('${idxItem.name}');`)
                                .then(indexCols => {
                                    _.forEach(indexCols, (idxCol: ISQLiteIndexColumn) => {

                                    });
                                });
                        });
                    });
                })
                .then(() => {
                    // Populate foreign key info
                    return Promise.each(fkInfoArray, (fkInfo: ISQLiteForeignKeyInfo[], idx: number) => {
                        if (fkInfo.length > 0) {
                            let tbl = self.tableInfo[idx];

                            _.forEach(fkInfo, (fk: ISQLiteForeignKeyInfo, idx: number) => {
                                fk.srcTable = tbl.table;
                                tbl.outFKeys.push(fk);

                                let outTbl = self.findTableInfoByName(fk.table);
                                if (!outTbl) {
                                    self.results.push({
                                        type: 'error',
                                        message: `Table specified in FKEY not found`, tableName: fk.table
                                    });
                                    return;
                                }

                                outTbl.inFKeys.push(fk);
                            });
                        }
                    });
                })
                .then(() => {
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
                    self.processReferenceProperties();

                    return resolve(self.outSchema);
                });
        });

        return result;
    }
}
