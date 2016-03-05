/**
 * Created by slanska on 2016-03-04.
 */

///<reference path="../models/definitions.d.ts"/>

import sqlite = require('sqlite3');
var Sync = require('syncho');
import _ = require('lodash');

namespace Flexilite
{
    interface SQLiteColumn
    {
        cid:number;
        name:string;
        type:string;
        notnull:number;
        dflt_value:any;
        pk:number;
    }

    interface SQLiteForeignKeyInfo
    {
        seq:number;
        table:string;
        from:string;
        to:string;
        on_update:string;
        on_delete:string;
        match:string;
    }

    export class ReverseEngine
    {
        private db:sqlite.Database;

        constructor(private sqliteConnectionString:string)
        {
            this.db = new sqlite.Database(sqliteConnectionString);
        }

        public loadSchemaFromDatabase():ISyncOptions
        {
            var result = {} as ISyncOptions;
            var self = this;
            Sync(()=>
            {
                try
                {
                    var tables = (self.db.all as any).sync(self.db, `select * from sqlite_master where type = 'table' and name not like 'sqlite%';`);
                    _.forEach(tables, (item:any) =>
                    {
                        console.log('Table: ', item.name);
                        let col_sql = `pragma table_info ('${item.name}');`;
                        var cols = (self.db.all as any).sync(self.db, col_sql) as SQLiteColumn[];
                        _.forEach(cols, (col:SQLiteColumn) =>
                        {
                            col.name;
                            col.type;
                        });
                        console.log(cols);

                        let fk_sql = `pragma foreign_key_list ('${item.name}');`;
                        var fkeys = (self.db.all as any).sync(self.db, fk_sql);
                        _.forEach(fkeys, (item:SQLiteForeignKeyInfo) =>
                        {
                            console.log(item);
                        });
                    });

                }
                catch (err)
                {
                    console.log(err);
                }
            });
            return result;
        }
    }
}

export = Flexilite.ReverseEngine;