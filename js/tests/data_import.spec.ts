/**
 * Created by slanska on 2016-05-01.
 */

/// <reference path="../../typings/tests.d.ts"/>

import helper = require('./helper');
import sqlite3 = require('../dbhelper');
import faker = require('faker');
import chai = require('chai');
import path = require('path');

let shortid = require('shortid');
// import {SQLiteDataRefactor} from '../lib/drivers/SQLite/SQLiteDataRefactor';

var expect = chai.expect;

describe('SQLite extensions: Flexilite EAV', () => {
    let db: sqlite3.Database;
    // let refactor: SQLiteDataRefactor;

    before((done: Function) => {
        helper.openDB('test_ttc.db')
            .then(database => {
                db = database;
                // refactor = new SQLiteDataRefactor(db);
                done();
            });
    });

    after((done: Function) => {
        if (db)
            db.closeAsync()
                .then(() => done());
        else done();
    });

    it('import Northwind to memory', (done: Function) => {
        done();
    });

    function importTable(tableName: string) {
        return db.runAsync(`delete from [${tableName}];`)
            .then(() => {

                let importOptions = {} as any; //IImportDatabaseOptions;
                importOptions.sourceTable = tableName;
                importOptions.sourceConnectionString = path.join(__dirname, "data", "ttc.db");

                importOptions.targetTable = tableName;

                // return refactor.importFromDatabase(importOptions);
            })
            .then(() => {

                return db.allAsync(`select count(*) as cnt from [${tableName}];`);
            })
            .then((cnt) => {

                console.log(`\nget ${tableName} count: ${cnt[0].cnt}`);
            });
    }

    it('import TTC.trips', (done: Function) => {
        importTable('trips')
            .then(() => done());
    });

    it('import TTC.agency', (done: Function) => {
        importTable('agency')
            .then(() => done());
    });

    it('import TTC.calendar', (done: Function) => {
        importTable('calendar')
            .then(() => done());

    });

    it('import TTC.calendar_dates', (done: Function) => {
        importTable('calendar_dates')
            .then(() => done());

    });

    it('import TTC.routes', (done: Function) => {
        importTable('routes')
            .then(() => done());

    });

    it('import TTC.shapes', (done: Function) => {
        importTable('shapes')
            .then(() => done());

    });

    it('import TTC.stop_times', (done: Function) => {
        importTable('stop_times')
            .then(() => done());

    });

// it('import TTC.stops', (done)=>
// {
//     Sync(()=>
//     {
//         importTable('stops');
//         done();
//     });
// });

    it('get trip count', (done: Function) => {
        db.allAsync(`select count(*) as cnt from [trips];`)
            .then(cnt => {
                console.log(`\nget trip count: ${cnt[0].cnt}`);
                done();
            });
    });
});

