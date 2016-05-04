/**
 * Created by slanska on 2016-05-01.
 */

/// <reference path="../typings/tests.d.ts"/>

var Sync = require('syncho');
import helper = require('./helper');
import sqlite3 = require('sqlite3');
import faker = require('faker');
import chai = require('chai');
import path = require('path');
var shortid = require('shortid');
import {SQLiteDataRefactor} from '../lib/drivers/SQLite/SQLiteDataRefactor';

var expect = chai.expect;

describe('SQLite extensions: Flexilite EAV', ()=>
{
    var db:sqlite3.Database;
    var refactor:SQLiteDataRefactor;

    before((done)=>
    {
        Sync(()=>
        {
            db = helper.openDB('test_ttc.db');
            // db = helper.openMemoryDB();
            refactor = new SQLiteDataRefactor(db);
            done();
        });
    });

    after((done)=>
    {
        Sync(()=>
        {
            if (db)
                db.close.sync(db);
            done();
        });
    });

    it('import Northwind to memory', (done)=>
    {
        Sync(()=>
        {
            // let rows = db.all.sync(db, `select * from Person where AddressLine1 like '%camp%'`);
            // let rows = db.all.sync(db, `select * from Person where city match 'south*' and email match 'kristi*'`);
            // console.log(rows.length);
            done();
        });
    });

    it('import TTC.trips', (done)=>
    {
        Sync(()=>
        {
            try
            {
                var cnt = db.all.sync(db, `select count(*) from [trips];`);
                console.log(`\nget trip count: ${cnt}`);

                let importOptions = {} as IImportDatabaseOptions;
                importOptions.sourceTable = 'trips';
                importOptions.sourceConnectionString = path.join(__dirname, "data", "ttc.db");

                importOptions.targetTable = 'trips';

                refactor.importFromDatabase(importOptions);

                var cnt = db.all.sync(db, `select count(*) from [trips];`);
                console.log(`\nget trip count: ${cnt}`);

            }
            catch (err)
            {
                console.error(err);
            }
            finally
            {
                done();
            }
        });
    });

    it('get trip count', (done)=>
    {
        Sync(()=>
        {
            var cnt = db.all.sync(db, `select count(*) from [trips];`);
            console.log(`\nget trip count: ${cnt}`);
            done();
        });
    });
});