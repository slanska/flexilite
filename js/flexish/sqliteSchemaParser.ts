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
 Row structure as returned by 'select * from sqlite_master'
 */
interface ISQLiteTableInfo {
    name: string;
    type: string
    tbl_name: string;
    root_page: number;
}

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

/*
 Structure of index info
 Returned by PRAGMA INDEX_LIST()
 */
interface ISQLiteIndexInfo {
    /*
     Sequential number
     */
    seq: number;

    /*
     Index name
     */
    name: string;

    /*
     0 - non-unique index
     1 - unique index
     */
    unique: number;

    /*
     TODO Need to confirm?
     'c' - column based index (standard index)
     'pk' - primary key
     '?' - expression based index (maybe, 'e' ?)
     */
    origin: string;

    /*
     0 - index is on rows
     1 - partial index is on subset of rows
     */
    partial: number;

    /*
     Extra attributes
     */
    columns?: ISQLiteIndexColumn[];
}

/*
 Structure of column information in index
 Returned pragma index_info
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
     Name of referenced table ("to" table)
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

    /*
     Additional attributes (not included into PRAGMA result)
     */
    srcTable?: string;

    processed?: boolean;
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
     Indicates that primary key for this table is multi-column
     */
    multiPKey: boolean;

    /*
     Column info mapping by column ID (number)
     */
    columns: Dictionary<ISQLiteColumn>;

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

    /*
     All existing indexes including not currently supported
     */
    indexes?: ISQLiteIndexInfo[];

    /*
     Subset of indexes, currently supported by Flexilite
     Does not include partial and/or expression indexes
     */
    supportedIndexes?: ISQLiteIndexInfo[];
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
                case 'image':
                    p.rules.type = 'binary';
                    // TODO Process subtype
                    break;

                case 'ntext':
                    p.rules.type = 'text';
                    p.rules.maxLength = 1 << 31 - 1;
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
     Determines which properties should be skipped during schema generation
     */
    private processColumns(tableName: string) {
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
    private processPropertyRoles(tableName: string) {
        let self = this;
        let ti = self.tableInfo[tableName];

        // Analyze indexes
        _.forEach(ti.indexes, (idx: ISQLiteIndexInfo) => {
            if (idx.columns.length === 1 && idx.unique) {
            }
        });

    }

    /*
     Loads all metadata for the SQLite table (columns, indexes, foreign keys)
     Builds complete ITableInfo and returns promise for it
     */
    private loadTableInfo(tblDef: ISQLiteTableInfo): Promise<ITableInfo> {
        let self = this;

        // Init resulting dictionary
        let modelDef = {
            properties: {},
            specialProperties: {}
        } as IClassDefinition;
        self.outSchema[tblDef.name] = modelDef;

        let tableInfo = {
            table: tblDef.name,
            columnCount: 0,
            columns: {},
            inFKeys: [],
            outFKeys: [],
            manyToManyTable: false,
            multiPKey: false
        } as ITableInfo;
        self.tableInfo.push(tableInfo);

        let result = self.db.allAsync(`pragma table_info ('${tblDef.name}');`)
        // Process columns
            .then((cols: ISQLiteColumn[]) => {
                _.forEach(cols, (col: ISQLiteColumn) => {
                    if (col.pk > 1 && !tableInfo.multiPKey) {
                        tableInfo.multiPKey = true;
                        let msg = {
                            type: 'warn',
                            message: `Multi-column primary key is not supported`,
                            tableName: tableInfo.table
                        } as IFlexishResultItem;
                        self.results.push(msg);
                    }
                    let prop = self.sqliteColToFlexiProp(col);

                    prop.rules.maxOccurences = 1;
                    prop.rules.minOccurences = Number(col.notnull);

                    if (col.pk === 1 && !tableInfo.multiPKey) {
                        // TODO Handle multiple column PKEY
                        prop.index = 'unique';
                    }

                    if (col.dflt_value)
                        prop.defaultValue = col.dflt_value;

                    modelDef.properties[col.name] = prop;

                    tableInfo.columns[col.cid] = col;
                    tableInfo.columnCount++;
                });

                return self.db.allAsync(`pragma index_list('${tblDef.name}')`);
            })
            // Process indexes
            .then((indexes: ISQLiteIndexInfo[]) => {
                let deferredIdxCols = [];

                tableInfo.indexes = indexes;
                tableInfo.supportedIndexes = _.filter(indexes, (idx) => {
                    return idx.partial === 0 && idx.origin.toLowerCase() === 'c';
                });

                // Process all supported indexes
                _.forEach(tableInfo.supportedIndexes, (idx: ISQLiteIndexInfo) => {
                    idx.columns = [];
                    deferredIdxCols.push(self.db.allAsync(`pragma index_info('${idx.name}')`));
                });
                return Promise
                    .each(deferredIdxCols, (idxCols: ISQLiteIndexColumn[], ii: number) => {
                        // Process index columns
                        _.forEach(idxCols, (idxCol) => {
                            tableInfo.supportedIndexes[ii].columns.push(idxCol);
                        });
                    })
                    .then(() => self.db.allAsync(`pragma foreign_key_list('${tblDef.name}')`));
            })
            // Process foreign keys
            .then((fkInfo: ISQLiteForeignKeyInfo[]) => {
                if (fkInfo.length > 0) {
                    _.forEach(fkInfo, (fk: ISQLiteForeignKeyInfo) => {
                        fk.srcTable = tableInfo.table;
                        fk.processed = false;
                        tableInfo.outFKeys.push(fk);

                        let outTbl = self.findTableInfoByName(fk.table);
                        if (!outTbl) {
                            self.results.push({
                                type: 'error',
                                message: `Table specified in FKEY not found`,
                                tableName: fk.table
                            });
                            return;
                        }

                        outTbl.inFKeys.push(fk);
                    });
                }
                return tableInfo;
            });

        return result as any;
    }

    private getIndexColumnNames(tbl: ITableInfo, idx: ISQLiteIndexInfo) {
        let result = [];
        _.forEach(idx.columns, (c: ISQLiteIndexColumn) => {
            result.push(tbl.columns[c.cid].name);
        });
        return result.join(',');
    }

    private processFlexiliteClassDef(tblInfo: ITableInfo) {

        let self = this;
        let classDef = self.outSchema[tblInfo.table];

        // Get primary field
        let pkCol = _.find(tblInfo.columns, (cc: ISQLiteColumn) => {
            return cc.pk === 1;
        });

        /*
         Process foreign keys. Defines reference properties.
         There are 3 cases:
         1) normal 1:N, (1 is defined in inFKeys, N - in outFKeys)
         2) extending 1:1, when outFKeys column is primary column
         3) many-to-many M:N, via special table with 2 columns which are foreign keys to other table(s)

         Note: currently Flexilite does not support multi-column primary keys, thus multi-column
         foreign keys are not supported either
         */

        let many2many = false;
        if (tblInfo.columnCount === 2 && tblInfo.outFKeys.length === 2
            && tblInfo.inFKeys.length === 1) {
            /*
             Candidate for many-to-many association
             Full condition: both columns are required
             Both columns are in outFKeys
             Primary key is on columns A and B
             There is another non unique index on column B
             */
            many2many = _.isEqual(_.map(tblInfo.columns, 'name'), _.map(tblInfo.outFKeys, 'from'));
        }

        if (many2many) {
            classDef.storage = 'flexi-rel';
            classDef.storageFlexiRel.master = {
                ownProperty: {$propertyName: tblInfo.outFKeys[0].from},
                refClass: {$className: tblInfo.outFKeys[0].table},
                refProperty: {$propertyName: tblInfo.outFKeys[0].to}
            };
            classDef.storageFlexiRel.master = {
                ownProperty: {$propertyName: tblInfo.outFKeys[1].from},
                refClass: {$className: tblInfo.outFKeys[1].table},
                refProperty: {$propertyName: tblInfo.outFKeys[1].to}
            };

            // No need to process indexing as this class will be used as a virtual table with no data
            return;
        }

        // Check for 1:1 relation
        let
            extCol = _.find(tblInfo.outFKeys, (fk: ISQLiteForeignKeyInfo) => {
                return pkCol && pkCol.name === fk.from;
            });

        if (extCol) {
            // set mixin class
            classDef.mixin = [{$className: extCol.table}];
            extCol.processed = true;
            _.remove(tblInfo.outFKeys, extCol);
        }

        /*
         Processing what has left and create reference properties
         Reference property gets name based on name of references table
         and, optionally, 'from' column, so for relation between Order->OrderDetails by OrderID
         (for both tables) 2 properties will be created:
         a) in Orders: OrderDetails
         b) in OrderDetails: Order (singular form of Orders)
         In case of name conflict, ref property gets fully qualified name:
         Order_OrderID, OrderDetails_OrderID

         'from' columns for outFKeys are converted to computed properties: they accept input value,
         treat it as uid property of master class and don't get stored.

         */
        _.forEach(tblInfo.outFKeys, (fk: ISQLiteForeignKeyInfo) => {
            // N : 1
            if (!fk.processed) {
                let cc = classDef.properties[fk.from];
                let pp = {
                    rules: {
                        type: 'reference',
                        minOccurences: cc.rules.minOccurences,
                        maxOccurences: Math.floor(Number.MAX_VALUE)
                    }
                } as IClassPropertyDef;
                let propName = Pluralize.singular(`${fk.table}`);
                if (classDef.properties.hasOwnProperty(propName))
                    propName += `_${fk.from}`;

                pp.refDef = {
                    $className: fk.table,
                    // TODO
                    $reverseMinOccurences: 0,
                    $reverseMaxOccurences: 1
                };
                classDef.properties[propName] = pp;
                // TODO on_update, on_delete
                fk.processed = true;
            }
        });

        _.forEach(tblInfo.inFKeys, (fk: ISQLiteForeignKeyInfo) => {
            // 1 : N

        });


        /*
         Set indexing
         */
        this.processUniqueTextIndexes(tblInfo, classDef);
        this.processUniqueNonTextIndexes(tblInfo, classDef);
        this.processUniqueMutiColumnIndexes(tblInfo, self);
        this.processNonUniqueIndexes(tblInfo, classDef);
    }

    private processNonUniqueIndexes(tblInfo: ITableInfo, classDef: IClassDefinition) {
        let nonUniqIndexes = _.filter(tblInfo.supportedIndexes,
            (idx) => {
                return idx.unique !== 1;
            });

        /*
         Pool of full text columns
         */
        let ftsCols = ['X1', 'X2', 'X3', 'X4'];

        /*
         Pool of rtree columns
         */
        let rtCols = ['A', 'B', 'C', 'D', 'E'];

        _.forEach(nonUniqIndexes, (idx) => {
            let col = tblInfo.columns[idx.columns[0].cid];
            let prop = classDef.properties[col.name];
            switch (prop.rules.type) {
                case 'text':
                    // try to apply full text index
                    if (ftsCols.length === 0) {
                        prop.index = 'index';
                    }
                    else {
                        let ftsCol = ftsCols.shift();
                        classDef.fullTextIndexing = classDef.fullTextIndexing || {};
                        classDef.fullTextIndexing[ftsCol] = col.name;
                        prop.index = 'fulltext';
                    }
                    break;

                case 'integer':
                case 'number':
                case 'datetime':
                    //try to apply r-tree index
                    if (rtCols.length === 0) {
                        prop.index = 'index';
                    }
                    else {
                        let rtCol = rtCols.shift();
                        classDef.rangeIndexing = classDef.rangeIndexing || {} as any;
                        classDef.rangeIndexing[rtCol + '0'] = col.name;
                        classDef.rangeIndexing[rtCol + '1'] = col.name;
                        prop.index = 'range';
                    }
                    break;

                default:
                    prop.index = 'index';
                    break;
            }
        });
    }

    private    processUniqueMutiColumnIndexes(tblInfo: ITableInfo, self: SQLiteSchemaParser) {
        let uniqMultiIndexes = _.filter(tblInfo.supportedIndexes,
            (idx) => {
                return idx.columns.length > 1 && idx.unique === 1;
            });

        _.forEach(uniqMultiIndexes, (idx) => {
            // Unique multi column indexes are not supported
            let msg = `Index [${idx.name}] by ${self.getIndexColumnNames(tblInfo, idx)} is ignored as multi-column unique indexes are not supported by Flexilite`;
            self.results.push({
                type: 'warn',
                message: msg,
                tableName: tblInfo.table
            });
        });
    }

    private processUniqueNonTextIndexes(tblInfo: ITableInfo, classDef: IClassDefinition) {
        // unique non-text one column indexes, sorted by type
        let uniqOtherIndexes = _.sortBy(_.filter(tblInfo.supportedIndexes,
            (idx) => {
                let tt = classDef.properties[tblInfo.columns[idx.columns[0].cid].name].rules.type;
                return idx.columns.length === 1 && idx.unique === 1
                    && (tt === 'integer' || tt === 'number' || tt === 'datetime' || tt === 'binary');
            }),
            (idx) => {
                let tt = classDef.properties[tblInfo.columns[idx.columns[0].cid].name].rules.type;
                switch (tt) {
                    case 'integer':
                        return 0;
                    case 'number':
                        return 1;
                    case 'binary':
                        return 2;
                    default:
                        return 3;
                }
            });

        if (uniqOtherIndexes.length > 0) {
            classDef.specialProperties.uid = tblInfo.columns[uniqOtherIndexes[0].columns[0].cid].name;
            _.forEach(uniqOtherIndexes, (idx: ISQLiteIndexInfo) => {
                let col = tblInfo.columns[idx.columns[0].cid];
                let prop = classDef.properties[col.name];
                if (prop.rules.type === 'binary' && prop.rules.maxLength === 16) {
                    classDef.specialProperties.autoUuid = tblInfo.columns[idx.columns[0].cid].name;
                }
            });
        }
    }

    private processUniqueTextIndexes(tblInfo: ITableInfo, classDef: IClassDefinition) {
        /*
         Split all indexes into the following categories:
         1) Unique one column, by text column: special property and unique index, sorted by max length
         2) Unique one column, date, number or integer: special property and unique index, sorted by type - with integer on top
         3) Unique multi-column indexes: currently not supported
         4) Non-unique: only first column gets indexed. Text - full text search or index. Numeric types - RTree or index
         */

        // Get all unique one column indexes on text columns. They might be considered as Code, Name or Description special properties
        let uniqTxtIndexes = _.sortBy(_.filter(tblInfo.supportedIndexes,
            (idx) => {
                return idx.columns.length === 1 && idx.unique === 1
                    && classDef.properties[tblInfo.columns[idx.columns[0].cid].name].rules.type === 'text';
            }),
            (idx) => {
                return classDef.properties[tblInfo.columns[idx.columns[0].cid].name].rules.maxLength;
            });

        if (uniqTxtIndexes.length > 0) {
            // Items assigned to code, name, description
            classDef.specialProperties.code = tblInfo.columns[uniqTxtIndexes[0].columns[0].cid].name;
            classDef.specialProperties.name = tblInfo.columns[uniqTxtIndexes[uniqTxtIndexes.length > 1 ? 1 : 0].columns[0].cid].name;
            classDef.specialProperties.description = tblInfo.columns[_.last(uniqTxtIndexes).columns[0].cid].name;
        }
    }

    /*
     Loads schema from SQLite database
     and parses it to Flexilite class definition
     Returns promise which resolves to dictionary of Flexilite classes
     */
    public parseSchema(): Promise < ClassDefCollection > {
        let self = this;
        self.outSchema = {};
        self.tableInfo = [];

        // Get list of tables (excluding internal tables)
        return self.db.allAsync(`select * from sqlite_master where type = 'table' and name not like 'sqlite%';`)
            .then((tables: ISQLiteTableInfo[]) => {
                let deferredTables = [];
                _.forEach(tables, (item: ISQLiteTableInfo) => {
                    deferredTables.push(self.loadTableInfo(item));
                });
                return Promise.each(deferredTables,
                    (tblInfo: ITableInfo) => self.processFlexiliteClassDef(tblInfo));
            })
            .then(() => self.outSchema);
    }
}

