/**
 * Created by slanska on 2016-04-08.
 */
"use strict";
/// <reference path="../../typings/tests.d.ts"/>
///<reference path="../typings/api.d.ts"/>
var helper = require('./helper');
var faker = require('faker');
var chai = require('chai');
var shortid = require('shortid');
var Promise = require('bluebird');
var expect = chai.expect;
describe('SQLite extensions: Flexilite EAV', function () {
    var db;
    var personMeta = {
        "properties": {
            "EmployeeID": {
                "rules": {
                    "type": "integer",
                    "maxOccurences": 1,
                    "minOccurences": 1
                },
                "index": "unique"
            },
            "LastName": {
                "rules": {
                    "type": "text",
                    "maxLength": 20,
                    "maxOccurences": 1,
                    "minOccurences": 1
                },
                "index": "fulltext"
            },
            "FirstName": {
                "rules": {
                    "type": "text",
                    "maxLength": 10,
                    "maxOccurences": 1,
                    "minOccurences": 1
                }
            },
            "Title": {
                "rules": {
                    "type": "text",
                    "maxLength": 30,
                    "maxOccurences": 1,
                    "minOccurences": 0
                }
            },
            "TitleOfCourtesy": {
                "rules": {
                    "type": "text",
                    "maxLength": 25,
                    "maxOccurences": 1,
                    "minOccurences": 0
                }
            },
            "BirthDate": {
                "rules": {
                    "type": "datetime",
                    "maxOccurences": 1,
                    "minOccurences": 0
                }
            },
            "HireDate": {
                "rules": {
                    "type": "datetime",
                    "maxOccurences": 1,
                    "minOccurences": 0
                }
            },
            "Address": {
                "rules": {
                    "type": "text",
                    "maxLength": 60,
                    "maxOccurences": 1,
                    "minOccurences": 0
                }
            },
            "City": {
                "rules": {
                    "type": "text",
                    "maxLength": 15,
                    "maxOccurences": 1,
                    "minOccurences": 0
                }
            },
            "Region": {
                "rules": {
                    "type": "text",
                    "maxLength": 15,
                    "maxOccurences": 1,
                    "minOccurences": 0
                }
            },
            "PostalCode": {
                "rules": {
                    "type": "text",
                    "maxLength": 10,
                    "maxOccurences": 1,
                    "minOccurences": 0
                },
                "index": "fulltext"
            },
            "Country": {
                "rules": {
                    "type": "text",
                    "maxLength": 15,
                    "maxOccurences": 1,
                    "minOccurences": 0
                }
            },
            "HomePhone": {
                "rules": {
                    "type": "text",
                    "maxLength": 24,
                    "maxOccurences": 1,
                    "minOccurences": 0
                }
            },
            "Extension": {
                "rules": {
                    "type": "text",
                    "maxLength": 4,
                    "maxOccurences": 1,
                    "minOccurences": 0
                }
            },
            "Photo": {
                "rules": {
                    "type": "binary",
                    "maxOccurences": 1,
                    "minOccurences": 0
                }
            },
            "Notes": {
                "rules": {
                    "type": "text",
                    "maxLength": 1073741824,
                    "maxOccurences": 1,
                    "minOccurences": 0
                }
            },
            "PhotoPath": {
                "rules": {
                    "type": "text",
                    "maxLength": 255,
                    "maxOccurences": 1,
                    "minOccurences": 0
                }
            }
        },
        "specialProperties": {
            "uid": "EmployeeID"
        },
        "fullTextIndexing": {
            "X1": "PostalCode",
            "X2": "LastName"
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
        helper.openDB("testA.db")
            .then(function (database) {
            db = database;
            done();
        });
    });
    after(function (done) {
        db.closeAsync()
            .then(function () { return done(); });
    });
    it('MATCH 2 on non-FTS-indexed columns', function (done) {
        // let rows = db.all.sync(db, `select * from Person where AddressLine1 like '%camp%'`);
        db.allAsync("select * from Person where city match 'south*' and email match 'kristi*'")
            .then(function (rows) {
            console.log(rows.length);
            done();
        });
    });
    it('MATCH 2 intersect on non-FTS-indexed columns', function (done) {
        // let rows = db.all.sync(db, `select * from Person where AddressLine1 like '%camp%'`);
        db.allAsync("select * from Person where city match 'south*' intersect \n            select * from Person where email match 'kristi*'")
            .then(function (rows) {
            console.log(rows.length);
            done();
        });
    });
    it('REGEXP 2', function (done) {
        // let rows = db.all.sync(db, `select * from Person where lower(city) regexp '.*south\\S*.*' and
        // lower(email) regexp '.*\\S*hotmail\\S*.*'`);
        db.allAsync("select * from Person where lower(city) regexp '.*south\\S*.*' and lower(email) regexp '.*kristi\\S*.*'")
            .then(function (rows) {
            // let rows = db.all.sync(db, `select * from Person where city regexp '.*south\\S*.*' and email regexp '.*\\S*hotmail\\S*.*'`);
            console.log(rows.length, rows);
            done();
        });
    });
    it('REGEXP 3', function (done) {
        // let rows = db.all.sync(db, `select * from Person where lower(city) regexp '.*south\\S*.*' and
        // lower(email) regexp '.*\\S*hotmail\\S*.*'`);
        db.allAsync("select * from Person where lower(city) regexp '.*south\\S*.*' \n            and lower(email) regexp '.*kristi\\S*.*'\n            and lower(country) regexp '.*ka\\S*.*'")
            .then(function (rows) {
            // let rows = db.all.sync(db, `select * from Person where city regexp '.*south\\S*.*' and email regexp '.*\\S*hotmail\\S*.*'`);
            console.log(rows.length, rows);
            done();
        });
    });
    it('MATCH 1 on non-FTS-indexed columns', function (done) {
        // let rows = db.all.sync(db, `select * from Person where AddressLine1 like '%camp%'`);
        db.allAsync("select * from Person where email match 'kristi*'")
            .then(function (rows) {
            console.log(rows.length);
            done();
        });
    });
    it('REGEXP 1', function (done) {
        // let rows = db.all.sync(db, `select * from Person where lower(city) regexp '.*south\\S*.*' and
        // lower(email) regexp '.*\\S*hotmail\\S*.*'`);
        db.allAsync("select * from Person where lower(email) regexp '.*kristi\\S*.*'")
            .then(function (rows) {
            // let rows = db.all.sync(db, `select * from Person where city regexp '.*south\\S*.*' and email regexp '.*\\S*hotmail\\S*.*'`);
            console.log(rows.length, "\n");
            done();
        });
    });
    it('linear scan', function (done) {
        // let rows = db.all.sync(db, `select * from Person where AddressLine1 like '%camp%'`);
        db.allAsync("select * from Person where city = 'South Kayden' ")
            .then(function (rows) {
            console.log('linear scan: ', rows.length);
            done();
        });
    });
    it('basic flow', function (done) {
        var def = JSON.stringify(personMeta);
        db.execAsync("create virtual table if not exists Person using 'flexi_eav' ('" + def + "');")
            .then(function () { return db.execAsync("begin transaction"); })
            .then(function () {
            var ops = [];
            for (var ii = 0; ii < 10000; ii++) {
                var person = randomPersonArguments();
                ops.push(db.runAsync("insert into Person (FirstName,\n                LastName,\n                Gender,\n                AddressLine1,\n                City,\n                StateOrProvince,\n                Country,\n                ZipOrPostalCode,\n                Email,\n                Phone) values (\n                $FirstName,\n                $LastName,\n                $Gender,\n                $AddressLine1,\n                $City,\n                $StateOrProvince,\n                $Country,\n                $ZipOrPostalCode,\n                $Email,\n                $Phone);", person));
            }
            return Promise.each(ops, function () {
            });
        })
            .then(function () { return db.execAsync("commit"); })
            .catch(function (err) {
            db.execAsync("rollback");
            throw err;
        })
            .finally(function () { return done(); });
    });
});
//# sourceMappingURL=flexi_eav.js.map