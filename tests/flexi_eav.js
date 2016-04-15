/**
 * Created by slanska on 2016-04-08.
 */
"use strict";
/// <reference path="../typings/tests.d.ts"/>
var Sync = require('syncho');
var helper = require('./helper');
var chai = require('chai');
var shortid = require('shortid');
var expect = chai.expect;
describe('SQLite extensions: Flexilite EAV', function () {
    var db;
    var personMeta = {
        properties: {
            FirstName: { rules: { type: 0 /* TEXT */, minOccurences: 1, maxOccurences: 1 } },
            LastName: { rules: { type: 0 /* TEXT */ } },
            Gender: { rules: { type: 6 /* ENUM */ } },
            AddressLine1: { rules: { type: 0 /* TEXT */ } },
            City: { rules: { type: 0 /* TEXT */ } },
            StateOrProvince: { rules: { type: 0 /* TEXT */ } },
            Country: { rules: { type: 0 /* TEXT */ } },
            ZipOrPostalCode: { rules: { type: 0 /* TEXT */ } },
            Email: { rules: { type: 0 /* TEXT */ } },
            Phone: { rules: { type: 0 /* TEXT */ } }
        }
    };
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
            var def = JSON.stringify(personMeta);
            db.exec.sync(db, "create virtual table Person using 'flexi_eav' ('" + def + "');");
            var rows = db.all.sync(db, "select * from Person where LastName = 'Doe';");
        });
    });
});
//# sourceMappingURL=flexi_eav.js.map