/**
 * Created by slanska on 2016-05-01.
 */
"use strict";
/// <reference path="../typings/tests.d.ts"/>
var Sync = require('syncho');
var helper = require('./helper');
var chai = require('chai');
var path = require('path');
var shortid = require('shortid');
var SQLiteDataRefactor_1 = require('../lib/drivers/SQLite/SQLiteDataRefactor');
var expect = chai.expect;
describe('SQLite extensions: Flexilite EAV', function () {
    var db;
    var refactor;
    before(function (done) {
        Sync(function () {
            db = helper.openDB('test_ttc.db');
            // db = helper.openMemoryDB();
            refactor = new SQLiteDataRefactor_1.SQLiteDataRefactor(db);
            done();
        });
    });
    after(function (done) {
        Sync(function () {
            if (db)
                db.close.sync(db);
            done();
        });
    });
    it('import Northwind to memory', function (done) {
        Sync(function () {
            done();
        });
    });
    function importTable(tableName) {
        try {
            db.run.sync(db, "delete from [" + tableName + "];");
            var importOptions = {};
            importOptions.sourceTable = tableName;
            importOptions.sourceConnectionString = path.join(__dirname, "data", "ttc.db");
            importOptions.targetTable = tableName;
            refactor.importFromDatabase(importOptions);
            var cnt = db.all.sync(db, "select count(*) as cnt from [" + tableName + "];");
            console.log("\nget " + tableName + " count: " + cnt[0].cnt);
        }
        catch (err) {
            console.error(err);
        }
    }
    it('import TTC.trips', function (done) {
        Sync(function () {
            importTable('trips');
            done();
        });
    });
    it('import TTC.agency', function (done) {
        Sync(function () {
            importTable('agency');
            done();
        });
    });
    it('import TTC.calendar', function (done) {
        Sync(function () {
            importTable('calendar');
            done();
        });
    });
    it('import TTC.calendar_dates', function (done) {
        Sync(function () {
            importTable('calendar_dates');
            done();
        });
    });
    it('import TTC.routes', function (done) {
        Sync(function () {
            importTable('routes');
            done();
        });
    });
    it('import TTC.shapes', function (done) {
        Sync(function () {
            importTable('shapes');
            done();
        });
    });
    it('import TTC.stop_times', function (done) {
        Sync(function () {
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
    it('get trip count', function (done) {
        Sync(function () {
            var cnt = db.all.sync(db, "select count(*) as cnt from [trips];");
            console.log("\nget trip count: " + cnt[0].cnt);
            done();
        });
    });
});
//# sourceMappingURL=data_import.spec.js.map