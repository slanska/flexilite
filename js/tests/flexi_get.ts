/**
 * Created by slanska on 2016-03-25.
 */

/// <reference path="../../typings/tests.d.ts"/>

import helper = require('./helper');
import sqlite3 = require('sqlite3');
import faker = require('faker');
import chai = require('chai');

let shortid = require('shortid');
let expect = chai.expect;

interface person1 {
    FirstName: string,
    LastName: string,
    Gender: 'M' | 'F',
    AddressLine1: string,
    City: string,
    StateOrProvince: string,
    Country: string,
    ZipOrPostalCode: string,
    Email: string,
    Phone: string
}

describe('SQLite extensions: flexi_get', () => {
    let db: sqlite3.Database;

    before((done: Function) => {
        helper.openMemoryDB()
            .then(database => {
                db = database;
                done();
            });
    });

    after((done: Function) => {
        db.closeAsync()
            .then(() => done());
    });

    beforeEach((done: Function) => {
        var p: person1 = {
            FirstName: faker.name.firstName(),
            LastName: faker.name.lastName(),
            Gender: faker.random.boolean() ? 'M' : 'F',
            AddressLine1: faker.address.streetAddress(),
            City: faker.address.city(),
            StateOrProvince: faker.address.state(),
            Country: faker.address.country(),
            ZipOrPostalCode: faker.address.zipCode(),
            Email: faker.internet.email(),
            Phone: faker.phone.phoneNumber()
        };
        done();
    });

    it('Basic JSON: direct', (done: Function) => {
        let json = JSON.stringify({abc: {xyz: ['Future will be ours', 'Crudbit Is Coming!']}});
        var rows = db.all.sync(db, `select typeof(Data), Data from (select flexi_get(11, 1001, json('{"properties":{"11":{"map":{"jsonPath": "$.abc.xyz[1]"}}}}'),
json('${json}')) as Data);`);

        expect(rows[0]['Data']).to.be.equal('Crudbit Is Coming!');
        done();
    });

    it('Basic JSON: nested attribute', (done: Function) => {
        done();
    });

    it('Basic JSON: item in array', (done: Function) => {
        done();
    });

    it('Basic JSON: item in nested array', (done: Function) => {
        done();
    });

    it('Basic JSON: with default value', (done: Function) => {
        done();
    });

    it('Basic JSON: with default value as null', (done: Function) => {
        done();
    });

    it('Indirect JSON: first item in collection', (done: Function) => {
        done();
    });

    it('Indirect JSON: last item in collection', (done: Function) => {
        done();
    });

    it('Indirect JSON: filter first item', (done: Function) => {
        done();
    });

    it('Indirect JSON: filter last item', (done: Function) => {
        done();
    });

    it('Indirect JSON: sorted first item', (done: Function) => {
        done();
    });

    it('Indirect JSON: sorted last item', (done: Function) => {
        done();
    });

    it('Indirect JSON: filtered and sorted first item', (done: Function) => {
        done();
    });

    it('Indirect JSON: filtered and sorted last item', (done: Function) => {
        done();
    });

    it('Indirect JSON: by specific index in collection', (done: Function) => {
        done();
    });
});

describe('SQLite extensions: var', () => {
    var db: sqlite3.Database;

    before((done: Function) => {
        helper.openMemoryDB()
            .then(d => {
                db = d;
                done();
            })
    });

    after((done: Function) => {
        db.close();
        done();
    });

    it('retrieves the same CurrentUserID', (done: Function) => {
        var rows = db.all.sync(db, `select var('currentuserid') as CurrentUserID`);
        expect(rows[0]['CurrentUserID']).to.deep.equal((db as any)['CurrentUserID']);

        done();
    });

    it('does not have memory leaks', (done: Function) => {
        function getMemStats() {
            var savedUserID = (db as any)['CurrentUserID'];
            var rows = db.all.sync(db, `select mem_used() as mem_used, mem_high_water() as mem_high_water;`);
            var memUsed = rows[0]['mem_used'];
            var memHighWater = rows[0]['mem_high_water'];
            return {userID: savedUserID, memUsed: memUsed, memHighWater: memHighWater};
        }

        var savedStats = getMemStats();
        for (var i = 0; i < 100000; i++) {
            var newID = shortid();
            db.run.sync(db, `select var('currentUserID', '${newID}');`);
        }
        var newStats = getMemStats();
        db.runAsync(`select var('currentUserID', ?);`, savedStats.userID)
            .then(() => db.closeAsync())
            .then(() => helper.openMemoryDB())
            .then(d => {
                db = d;
                done();
            });
    });
});

describe('SQLite extensions: hash', () => {
    var db: sqlite3.Database;

    before((done: Function) => {
        helper.openMemoryDB().then(d => {
            db = d;
            done();
        });
    });

    after((done: Function) => {
        db.closeAsync()
            .then(() => done());
    });

    it('generates basic hash', (done: Function) => {
        var rows = db.all.sync(db, `select hash('Crudbit will win!') as hash;`);
        var hash = rows[0].hash;
        console.log(`Hash: ${hash}`);
        done();
    });
});

describe('SQLite extensions: eval', () => {
});

describe('SQLite extensions: fileio', () => {
});

describe('SQLite extensions: regexp', () => {
});

describe('SQLite extensions: compress', () => {
});