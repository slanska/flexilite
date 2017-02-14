/**
 * Created by slanska on 2016-05-01.
 */
"use strict";
/// <reference path="../../typings/tests.d.ts"/>
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
        helper.openDB('test_ttc.db')
            .then(function (database) {
            db = database;
            refactor = new SQLiteDataRefactor_1.SQLiteDataRefactor(db);
            done();
        });
    });
    after(function (done) {
        if (db)
            db.closeAsync()
                .then(function () { return done(); });
        else
            done();
    });
    it('import Northwind to memory', function (done) {
        done();
    });
    function importTable(tableName) {
        return db.runAsync("delete from [" + tableName + "];")
            .then(function () {
            var importOptions = {}; //IImportDatabaseOptions;
            importOptions.sourceTable = tableName;
            importOptions.sourceConnectionString = path.join(__dirname, "data", "ttc.db");
            importOptions.targetTable = tableName;
            return refactor.importFromDatabase(importOptions);
        })
            .then(function () {
            return db.allAsync("select count(*) as cnt from [" + tableName + "];");
        })
            .then(function (cnt) {
            console.log("\nget " + tableName + " count: " + cnt[0].cnt);
        });
    }
    it('import TTC.trips', function (done) {
        importTable('trips')
            .then(function () { return done(); });
    });
    it('import TTC.agency', function (done) {
        importTable('agency')
            .then(function () { return done(); });
    });
    it('import TTC.calendar', function (done) {
        importTable('calendar')
            .then(function () { return done(); });
    });
    it('import TTC.calendar_dates', function (done) {
        importTable('calendar_dates')
            .then(function () { return done(); });
    });
    it('import TTC.routes', function (done) {
        importTable('routes')
            .then(function () { return done(); });
    });
    it('import TTC.shapes', function (done) {
        importTable('shapes')
            .then(function () { return done(); });
    });
    it('import TTC.stop_times', function (done) {
        importTable('stop_times')
            .then(function () { return done(); });
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
        db.allAsync(db, "select count(*) as cnt from [trips];")
            .then(function (cnt) {
            console.log("\nget trip count: " + cnt[0].cnt);
            done();
        });
    });
});
//# sourceMappingURL=data_import.spec.js.map