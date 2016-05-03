/**
 * Created by slanska on 2016-05-01.
 */
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports", './helper', 'chai', 'path', '../lib/drivers/SQLite/SQLiteDataRefactor'], factory);
    }
})(function (require, exports) {
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
                db = helper.openMemoryDB();
                refactor = new SQLiteDataRefactor_1.SQLiteDataRefactor(db);
                done();
            });
        });
        after(function (done) {
            Sync(function () {
                db.close.sync(db);
                done();
            });
        });
        it('import Northwind to memory', function (done) {
            Sync(function () {
                // let rows = db.all.sync(db, `select * from Person where AddressLine1 like '%camp%'`);
                // let rows = db.all.sync(db, `select * from Person where city match 'south*' and email match 'kristi*'`);
                // console.log(rows.length);
                done();
            });
        });
        it('import TTC.trips to memory', function (done) {
            Sync(function () {
                try {
                    var importOptions = {};
                    importOptions.sourceTable = 'trips';
                    importOptions.sourceConnectionString = path.join(__dirname, "data", "ttc.db");
                    importOptions.targetTable = 'trips';
                    refactor.importFromDatabase(importOptions);
                }
                catch (err) {
                    console.error(err);
                }
                finally {
                    done();
                }
            });
        });
    });
});
//# sourceMappingURL=data_import.spec.js.map