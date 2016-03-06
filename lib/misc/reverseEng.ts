/**
 * Created by slanska on 2016-03-04.
 */


///<reference path="../models/definitions.d.ts"/>
/// <reference path="../../typings/node/node.d.ts"/>
/// <reference path="../../node_modules/orm/lib/TypeScript/orm.d.ts" />
/// <reference path="../../typings/tsd.d.ts" />

'use strict';

import sqlite = require('sqlite3');
var Sync = require('syncho');
import _ = require('lodash');

module Flexilite
{
    interface SQLiteColumn
    {
        cid:number;
        name:string;

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
        type:string;
        notnull:number;
        dflt_value:any;

        /*
         Position in primary key, starting from 1, or 0, if column
         is not a part of primary key
         */
        pk:number;
    }

    interface SQLiteIndexInfo
    {
        seq:number;
        cid:number;
        name:string;
    }

    interface SQLiteIndexXInfo extends SQLiteIndexInfo
    {
        unique:number | boolean;
        origin:string;
        partial:number | boolean;
    }

    interface SQLiteIndexColumn
    {
        seq:number;
        cid:number;
        name:string;
        desc:number;
        coll:string;
        key:number | boolean;
    }

    /*
     Contract for foreign key information as returned by SQLite
     PRAGMA foreign_key_list('table_name')
     */
    interface SQLiteForeignKeyInfo
    {
        /*
         Sequenial number
         */
        seq:number;

        /*
         Name of referenced table
         */
        table:string;

        /*
         Name of column(s) in the source table
         */
        from:string;

        /*
         Name of column(s) in the referenced table
         */
        to:string;

        /*
         There are following values expected for these 2 fields:
         NONE
         NO_ACTION - loose relation
         CASCADE - parentship
         RESTRICT - "partnership"
         SET_NULL
         SET_DEFAULT

         */
        on_update:string;
        on_delete:string;

        /*
         Possible values:
         MATCH
         ???
         */
        match:string;
    }

    export class ReverseEngine
    {
        private db:sqlite.Database;

        constructor(private sqliteConnectionString:string)
        {
            this.db = new sqlite.Database(sqliteConnectionString);
        }

        /*

         */
        private static sqliteTypeToOrmType(type:string):{type: string, size?: number, time?: boolean}
        {
            if (_.isNull(type))
                return {type: 'text'};

            switch (type.toLowerCase())
            {
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
                    if (matches.length === 3)
                    {
                        if (matches[1] === 'blob')
                            return {type: 'binary', size: Number(matches[2])};

                        if (matches[1] === 'numeric')
                        {
                            return {type: 'number'};
                        }

                        return {type: 'text', size: Number(matches[2])};
                    }
                    return {type: 'text'};
            }
        }

        /*

         */
        public getPropertiesFromORMDriverSchema(schema:ISyncOptions):{[propName:string]:IPropertyDef}
        {
            var result = {} as {[propName:string]:IPropertyDef};
            _.forEach(schema.properties, (prop:IPropertyDef) =>
            {
                result[prop.name] = prop;
            });
            return result;
        }

        /*
         Retrieves all database metadata and returns array of model definitions in the format
         expected by node-orm2 Driver.
         */
        public loadSchemaFromDatabase(callback:Function)
        {
            var self = this;
            Sync(()=>
            {
                var result:{[name:string]: ISyncOptions} = {};
                try
                {
                    var tables = self.db.all.sync(self.db,
                        `select * from sqlite_master where type = 'table' and name not like 'sqlite%';`);
                    _.forEach(tables, (item:any) =>
                    {
                        var modelDef = {} as ISyncOptions;

                        result[item.name] = modelDef;

                        let col_sql = `pragma table_info ('${item.name}');`;
                        var cols = self.db.all.sync(self.db, col_sql) as SQLiteColumn[];
                        _.forEach(cols, (col:SQLiteColumn) =>
                        {
                            var prop = ReverseEngine.sqliteTypeToOrmType(col.type) as IPropertyDef;
                            prop.indexed = col.pk !== 0;
                            prop.name = col.name;

                            prop.defaultValue = col.dflt_value;
                            prop.mapsTo = col.name;
                            prop.unique = col.pk !== 0;

                            // Set primary key
                            if (col.pk && col.pk !== 0)
                            {
                                if (!modelDef.id)
                                    modelDef.id = [];
                                modelDef.id[col.pk - 1] = col.name;
                            }

                            if (!modelDef.properties)
                                modelDef.properties = [];
                            modelDef.properties.push(prop);

                        });

                        var indexList = self.db.all.sync(self.db, `pragma index_list ('${item.name}');`);
                        _.forEach(indexList, (idxItem:SQLiteIndexXInfo) =>
                        {
                            var indexCols = (self.db.all as any).sync(self.db, `pragma index_xinfo ('${idxItem.name}');`);
                            _.forEach(indexCols, (idxCol:SQLiteIndexColumn) =>
                            {

                            });
                        });

                        let fk_sql = `pragma foreign_key_list ('${item.name}');`;
                        var fkeys = self.db.all.sync(self.db, fk_sql);
                        _.forEach(fkeys, (item:SQLiteForeignKeyInfo) =>
                        {
                            var oneAssoc = {} as IHasOneAssociation;
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
                            var manyAssoc = {} as IHasManyAssociation;
                        });
                    });

                    callback(null, result);
                }
                catch (err)
                {
                    callback(err, result);
                }
            });

        }
    }
}

export = Flexilite;



