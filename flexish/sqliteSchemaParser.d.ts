/*
 * Created by slanska on 2017-11-18.
 */

/*
Declarations of objects and API used by sqliteSchemaParser.lus
 */


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

type ClassDefCollection = { [name: string]: IClassDefinition };

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
    columns: { [columnID: number]: ISQLiteColumn };

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
