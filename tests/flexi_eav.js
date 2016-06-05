/**
 * Created by slanska on 2016-04-08.
 */
"use strict";
/// <reference path="../typings/tests.d.ts"/>
var Sync = require('syncho');
var helper = require('./helper');
var faker = require('faker');
var chai = require('chai');
var shortid = require('shortid');
var expect = chai.expect;
describe('SQLite extensions: Flexilite EAV', function () {
    var db;
    var personMeta = {
        properties: {
            FirstName: { rules: { type: 25 /* PROP_TYPE_TEXT */, minOccurences: 1, maxOccurences: 1 } },
            LastName: { rules: { type: 25 /* PROP_TYPE_TEXT */ } },
            Gender: { rules: { type: 16 /* PROP_TYPE_ENUM */ } },
            AddressLine1: { rules: { type: 25 /* PROP_TYPE_TEXT */ } },
            City: { rules: { type: 25 /* PROP_TYPE_TEXT */ } },
            StateOrProvince: { rules: { type: 25 /* PROP_TYPE_TEXT */ } },
            Country: { rules: { type: 25 /* PROP_TYPE_TEXT */ } },
            ZipOrPostalCode: { rules: { type: 25 /* PROP_TYPE_TEXT */ } },
            Email: { rules: { type: 25 /* PROP_TYPE_TEXT */ } },
            Phone: { rules: { type: 25 /* PROP_TYPE_TEXT */ } }
        }
    };
    function randomPersonArguments() {
        var gender = faker.random.number(1);
        var result = {
            $FirstName: faker.name.firstName(gender),
            $LastName: faker.name.lastName(gender),
            $Gender: gender,
            $AddressLine1: faker.address.streetAddress(),
            $City: faker.address.city(),
            $StateOrProvince: faker.address.stateAbbr(),
            $Country: faker.address.country(),
            $ZipOrPostalCode: faker.address.zipCode(),
            $Email: faker.internet.email(),
            $Phone: faker.phone.phoneNumber()
        };
        return result;
    }
    before(function (done) {
        Sync(function () {
            // db = helper.openMemoryDB();
            db = helper.openDB("testA.db");
            done();
        });
    });
    after(function (done) {
        Sync(function () {
            db.close.sync(db);
            done();
        });
    });
    it('MATCH 2 on non-FTS-indexed columns', function (done) {
        Sync(function () {
            // let rows = db.all.sync(db, `select * from Person where AddressLine1 like '%camp%'`);
            var rows = db.all.sync(db, "select * from Person where city match 'south*' and email match 'kristi*'");
            console.log(rows.length);
            done();
        });
    });
    it('MATCH 2 intersect on non-FTS-indexed columns', function (done) {
        Sync(function () {
            // let rows = db.all.sync(db, `select * from Person where AddressLine1 like '%camp%'`);
            var rows = db.all.sync(db, "select * from Person where city match 'south*' intersect \n            select * from Person where email match 'kristi*'");
            console.log(rows.length);
            done();
        });
    });
    it('REGEXP 2', function (done) {
        Sync(function () {
            // let rows = db.all.sync(db, `select * from Person where lower(city) regexp '.*south\\S*.*' and
            // lower(email) regexp '.*\\S*hotmail\\S*.*'`);
            var rows = db.all.sync(db, "select * from Person where lower(city) regexp '.*south\\S*.*' and lower(email) regexp '.*kristi\\S*.*'");
            // let rows = db.all.sync(db, `select * from Person where city regexp '.*south\\S*.*' and email regexp '.*\\S*hotmail\\S*.*'`);
            console.log(rows.length, rows);
            done();
        });
    });
    it('REGEXP 3', function (done) {
        Sync(function () {
            // let rows = db.all.sync(db, `select * from Person where lower(city) regexp '.*south\\S*.*' and
            // lower(email) regexp '.*\\S*hotmail\\S*.*'`);
            var rows = db.all.sync(db, "select * from Person where lower(city) regexp '.*south\\S*.*' \n            and lower(email) regexp '.*kristi\\S*.*'\n            and lower(country) regexp '.*ka\\S*.*'");
            // let rows = db.all.sync(db, `select * from Person where city regexp '.*south\\S*.*' and email regexp '.*\\S*hotmail\\S*.*'`);
            console.log(rows.length, rows);
            done();
        });
    });
    it('MATCH 1 on non-FTS-indexed columns', function (done) {
        Sync(function () {
            // let rows = db.all.sync(db, `select * from Person where AddressLine1 like '%camp%'`);
            var rows = db.all.sync(db, "select * from Person where email match 'kristi*'");
            console.log(rows.length);
            done();
        });
    });
    it('REGEXP 1', function (done) {
        Sync(function () {
            // let rows = db.all.sync(db, `select * from Person where lower(city) regexp '.*south\\S*.*' and
            // lower(email) regexp '.*\\S*hotmail\\S*.*'`);
            var rows = db.all.sync(db, "select * from Person where lower(email) regexp '.*kristi\\S*.*'");
            // let rows = db.all.sync(db, `select * from Person where city regexp '.*south\\S*.*' and email regexp '.*\\S*hotmail\\S*.*'`);
            console.log(rows.length, "\n");
            done();
        });
    });
    it('linear scan', function (done) {
        Sync(function () {
            // let rows = db.all.sync(db, `select * from Person where AddressLine1 like '%camp%'`);
            var rows = db.all.sync(db, "select * from Person where city = 'South Kayden' ");
            console.log('linear scan: ', rows.length);
            done();
        });
    });
    it('basic flow', function (done) {
        Sync(function () {
            var def = JSON.stringify(personMeta);
            db.exec.sync(db, "create virtual table if not exists Person using 'flexi_eav' ('" + def + "');");
            db.exec.sync(db, "begin transaction");
            try {
                for (var ii = 0; ii < 10000; ii++) {
                    var person = randomPersonArguments();
                    db.run.sync(db, "insert into Person (FirstName,\n                LastName,\n                Gender,\n                AddressLine1,\n                City,\n                StateOrProvince,\n                Country,\n                ZipOrPostalCode,\n                Email,\n                Phone) values (\n                $FirstName,\n                $LastName,\n                $Gender,\n                $AddressLine1,\n                $City,\n                $StateOrProvince,\n                $Country,\n                $ZipOrPostalCode,\n                $Email,\n                $Phone);", person);
                }
                db.exec.sync(db, "commit");
            }
            catch (err) {
                db.exec.sync(db, "rollback");
                throw err;
            }
            done();
        });
    });
});
//# sourceMappingURL=flexi_eav.js.map