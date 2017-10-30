/**
 * Created by slanska on 2016-04-08.
 */

/// <reference path="../../typings/tests.d.ts"/>
///<reference path="../typings/api.d.ts"/>

import helper = require('./helper');
import sqlite3 = require('sqlite3');
import faker = require('faker');
import chai = require('chai');

var shortid = require('shortid');
import Promise = require('bluebird');

var expect = chai.expect;

describe('SQLite extensions: Flexilite EAV', () => {
    let db: sqlite3.Database;

    const personMeta = {
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
    } as IClassDefinition;

    function randomPersonArguments(): any {
        let gender = faker.random.number(1);
        let result = {
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

    before((done: Function) => {
        helper.openDB("testA.db")
            .then(database => {
                db = database;
                done();
            });
    });

    after((done: Function) => {
        db.closeAsync()
            .then(() => done());
    });

    it('MATCH 2 on non-FTS-indexed columns', (done: Function) => {
        // let rows = db.all.sync(db, `select * from Person where AddressLine1 like '%camp%'`);
        db.allAsync(`select * from Person where city match 'south*' and email match 'kristi*'`)
            .then(rows => {
                console.log(rows.length);
                done();
            });
    });

    it('MATCH 2 intersect on non-FTS-indexed columns', (done: Function) => {
        // let rows = db.all.sync(db, `select * from Person where AddressLine1 like '%camp%'`);
        db.allAsync(`select * from Person where city match 'south*' intersect 
            select * from Person where email match 'kristi*'`)
            .then(rows => {
                console.log(rows.length);
                done();
            });
    });

    it('REGEXP 2', (done: Function) => {
        // let rows = db.all.sync(db, `select * from Person where lower(city) regexp '.*south\\S*.*' and
        // lower(email) regexp '.*\\S*hotmail\\S*.*'`);
        db.allAsync(`select * from Person where lower(city) regexp '.*south\\S*.*' and lower(email) regexp '.*kristi\\S*.*'`)
            .then(rows => {
                // let rows = db.all.sync(db, `select * from Person where city regexp '.*south\\S*.*' and email regexp '.*\\S*hotmail\\S*.*'`);
                console.log(rows.length, rows);
                done();
            });
    });

    it('REGEXP 3', (done: Function) => {
        // let rows = db.all.sync(db, `select * from Person where lower(city) regexp '.*south\\S*.*' and
        // lower(email) regexp '.*\\S*hotmail\\S*.*'`);
        db.allAsync(`select * from Person where lower(city) regexp '.*south\\S*.*' 
            and lower(email) regexp '.*kristi\\S*.*'
            and lower(country) regexp '.*ka\\S*.*'`)
            .then(rows => {
                // let rows = db.all.sync(db, `select * from Person where city regexp '.*south\\S*.*' and email regexp '.*\\S*hotmail\\S*.*'`);
                console.log(rows.length, rows);
                done();
            });
    });

    it('MATCH 1 on non-FTS-indexed columns', (done: Function) => {

        // let rows = db.all.sync(db, `select * from Person where AddressLine1 like '%camp%'`);
        db.allAsync(`select * from Person where email match 'kristi*'`)
            .then(rows => {
                console.log(rows.length);
                done();
            });
    });

    it('REGEXP 1', (done: Function) => {
        // let rows = db.all.sync(db, `select * from Person where lower(city) regexp '.*south\\S*.*' and
        // lower(email) regexp '.*\\S*hotmail\\S*.*'`);
        db.allAsync(`select * from Person where lower(email) regexp '.*kristi\\S*.*'`)
            .then(rows => {
                // let rows = db.all.sync(db, `select * from Person where city regexp '.*south\\S*.*' and email regexp '.*\\S*hotmail\\S*.*'`);
                console.log(rows.length, "\n");
                done();
            });
    });

    it('linear scan', (done: Function) => {
        // let rows = db.all.sync(db, `select * from Person where AddressLine1 like '%camp%'`);
        db.allAsync(`select * from Person where city = 'South Kayden' `)
            .then(rows => {
                console.log('linear scan: ', rows.length);
                done();
            });
    });

    it('basic flow', (done: Function) => {
        let def = JSON.stringify(personMeta);
        db.execAsync(`create virtual table if not exists Person using 'flexi_eav' ('${def}');`)
            .then(() => db.execAsync(`begin transaction`))
            .then(() => {
                let ops = [];
                for (let ii = 0; ii < 10000; ii++) {
                    let person = randomPersonArguments();
                    ops.push(db.runAsync(`insert into Person (FirstName,
                LastName,
                Gender,
                AddressLine1,
                City,
                StateOrProvince,
                Country,
                ZipOrPostalCode,
                Email,
                Phone) values (
                $FirstName,
                $LastName,
                $Gender,
                $AddressLine1,
                $City,
                $StateOrProvince,
                $Country,
                $ZipOrPostalCode,
                $Email,
                $Phone);`, person));
                }
                return Promise.each(ops, () => {
                });
            })
            .then(() => db.execAsync(`commit`))

            .catch(err => {
                    db.execAsync(`rollback`);
                    throw err;
                }
            )
            .finally(() => done());
    });
});