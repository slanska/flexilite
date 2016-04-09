/**
 * Created by slanska on 2016-04-08.
 */
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports", './helper', 'chai'], factory);
    }
})(function (require, exports) {
    "use strict";
    /// <reference path="../typings/tests.d.ts"/>
    var Sync = require('syncho');
    var helper = require('./helper');
    var chai = require('chai');
    var shortid = require('shortid');
    var expect = chai.expect;
    describe('SQLite extensions: Flexilite EAV', function () {
        var db;
        before(function (done) {
            Sync(function () {
                db = helper.openMemoryDB();
                done();
            });
        });
        after(function (done) {
            Sync(function () {
                db.close.sync(db);
                done();
            });
        });
        it('basic flow', function (done) {
            Sync(function () {
                db.exec.sync(db, "create virtual table Person using 'flexi_eav' (\n            FirstName text,\n    LastName text,\n    Gender char,\n    AddressLine1 text,\n    City text,\n    StateOrProvince text,\n    Country text,\n    ZipOrPostalCode text,\n    Email text,\n    Phone text\n        );");
                var rows = db.all.sync(db, "select * from Person where LastName = 'Doe';");
            });
        });
    });
});
//# sourceMappingURL=flexi_eav.js.map