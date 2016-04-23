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
    it('basic flow', function (done) {
        Sync(function () {
            var def = JSON.stringify(personMeta);
            db.exec.sync(db, "create virtual table if not exists Person using 'flexi_eav' ('" + def + "');");
            db.exec.sync(db, "begin transaction");
            try {
                for (var ii = 0; ii < 1000; ii++) {
                    var person = randomPersonArguments();
                    db.run.sync(db, "insert into Person (FirstName,\n                LastName,\n                Gender,\n                AddressLine1,\n                City,\n                StateOrProvince,\n                Country,\n                ZipOrPostalCode,\n                Email,\n                Phone) values (\n                $FirstName,\n                $LastName,\n                $Gender,\n                $AddressLine1,\n                $City,\n                $StateOrProvince,\n                $Country,\n                $ZipOrPostalCode,\n                $Email,\n                $Phone);", person);
                }
                db.exec.sync(db, "commit");
            }
            catch (err) {
                db.exec.sync(db, "rollback");
                throw err;
            }
            var rows = db.all.sync(db, "select Country, rowid, LastName from Person where Country = 'Nepal';");
            // var rows = db.all.sync(db, `select * from Person where (LastName = 'Doe' and FirstName in ('John', 'Mary',
            //  'Peter')) or Phone like '%555%';`);
            // var rows = db.all.sync(db, `select * from Person where  FirstName >= 'John' and LastName = 'Smi';`);
            // var rows = db.all.sync(db, `select * from Person where (LastName = 'Doe' and FirstName in ('John', 'Mary',
            //  'Peter')) ;`);
            console.log(rows);
            done();
        });
    });
});
//# sourceMappingURL=flexi_eav.js.map