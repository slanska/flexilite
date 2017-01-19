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
            done();
        });
    });

    function importTable(tableName:string)
    {
        try
        {
            db.run.sync(db, `delete from [${tableName}];`);

            let importOptions = {} as IImportDatabaseOptions;
            importOptions.sourceTable = tableName;
            importOptions.sourceConnectionString = path.join(__dirname, "data", "ttc.db");

            importOptions.targetTable = tableName;

            refactor.importFromDatabase(importOptions);

            var cnt = db.all.sync(db, `select count(*) as cnt from [${tableName}];`);
            console.log(`\nget ${tableName} count: ${cnt[0].cnt}`);
        }
        catch (err)
        {
            console.error(err);
        }
    }

    it('import TTC.trips', (done)=>
    {
        Sync(()=>
        {
            importTable('trips');
            done();
        });
    });

    it('import TTC.agency', (done)=>
    {
        Sync(()=>
        {
            importTable('agency');
            done();
        });
    });

    it('import TTC.calendar', (done)=>
    {
        Sync(()=>
        {
            importTable('calendar');
            done();
        });
    });

    it('import TTC.calendar_dates', (done)=>
    {
        Sync(()=>
        {
            importTable('calendar_dates');
            done();
        });
    });

    it('import TTC.routes', (done)=>
    {
        Sync(()=>
        {
            importTable('routes');
            done();
        });
    });

    it('import TTC.shapes', (done)=>
    {
        Sync(()=>
        {
            importTable('shapes');
            done();
        });
    });

    it('import TTC.stop_times', (done)=>
    {
        Sync(()=>
        {
            importTable('stop_times');
            done();
        });
    });

    // it('import TTC.stops', (done)=>
    // {
    //     Sync(()=>
    //     {
    //         importTable('stops');
    //         done();
    //     });
    // });

    it('get trip count', (done)=>
    {
        Sync(()=>
        {
            var cnt = db.all.sync(db, `select count(*) as cnt from [trips];`);
            console.log(`\nget trip count: ${cnt[0].cnt}`);
            done();
        });
    });
});