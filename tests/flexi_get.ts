/**
 * Created by slanska on 2016-03-25.
 */

/// <reference path="../typings/mocha/mocha.d.ts"/>
// / <reference path="../typings/node/node.d.ts"/>
// / <reference path="../typings/chai/chai.d.ts" />
/// <reference path="../typings/tsd.d.ts" />
/// <reference path="../node_modules/orm/lib/TypeScript/orm.d.ts"/>
/// <reference path="../node_modules/orm/lib/TypeScript/sql-query.d.ts"/>

var Sync = require('syncho');
import helper = require('./helper');
import sqlite3 = require('sqlite3');
import faker = require('faker');
import chai = require('chai');
var shortid = require('shortid');

var expect = chai.expect;

interface person1
{
    FirstName:string,
    LastName:string,
    Gender:'M' | 'F',
    AddressLine1:string,
    City:string,
    StateOrProvince:string,
    Country:string,
    ZipOrPostalCode:string,
    Email:string,
    Phone:string
}

describe('SQLite extensions: flexi_get', ()=>
{
    var db:sqlite3.Database;

    before((done)=>
    {
        Sync(()=>
        {
            db = helper.openMemoryDB();
            done();
        });
    });

    after((done)=>
    {
        Sync(()=>
        {
            db.close.sync(db);
            done();
        });
    });

    beforeEach((done)=>
    {
        var p:person1 = {
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

    it('Basic JSON: direct', (done)=>
    {
        Sync(()=>
        {
            let json = JSON.stringify({abc: {xyz: ['Future will be ours', 'Crudbit Is Coming!']}});
            var rows = db.all.sync(db, `select typeof(Data), Data from (select flexi_get(11, 1001, json('{"properties":{"11":{"map":{"jsonPath": "$.abc.xyz[1]"}}}}'),
json('${json}')) as Data);`);

            expect(rows[0]['Data']).to.be.equal('Crudbit Is Coming!');
            done();
        });
    });

    it('Basic JSON: nested attribute', (done)=>
    {
        done();
    });

    it('Basic JSON: item in array', (done)=>
    {
        done();
    });

    it('Basic JSON: item in nested array', (done)=>
    {
        done();
    });


    it('Basic JSON: with default value', (done)=>
    {
        done();
    });


    it('Basic JSON: with default value as null', (done)=>
    {
        done();
    });


    it('Indirect JSON: first item in collection', (done)=>
    {
        done();
    });

    it('Indirect JSON: last item in collection', (done)=>
    {
        done();
    });


    it('Indirect JSON: filter first item', (done)=>
    {
        done();
    });

    it('Indirect JSON: filter last item', (done)=>
    {
        done();
    });

    it('Indirect JSON: sorted first item', (done)=>
    {
        done();
    });

    it('Indirect JSON: sorted last item', (done)=>
    {
        done();
    });

    it('Indirect JSON: filtered and sorted first item', (done)=>
    {
        done();
    });

    it('Indirect JSON: filtered and sorted last item', (done)=>
    {
        done();
    });

    it('Indirect JSON: by specific index in collection', (done)=>
    {
        done();
    });


});

describe('SQLite extensions: var', ()=>
{
    var db:sqlite3.Database;

    before((done)=>
    {
        Sync(()=>
        {
            db = helper.openMemoryDB();
            done();
        });
    });

    after((done)=>
    {
        Sync(()=>
        {
            db.close();
            done();
        });
    });

    it('get CurrentUserID', (done)=>
    {
        Sync(()=>
        {
            var rows = db.all.sync(db, `select var('currentuserid') as CurrentUserID`);
            expect(rows[0]['CurrentUserID']).to.deep.equal(db['CurrentUserID']);

            done();
        });
    });

    it('run in a loop', (done)=>
    {
        Sync(()=>
        {
            function getMemStats()
            {
                var savedUserID = db['CurrentUserID'];
                var rows = db.all.sync(db, `select mem_used() as mem_used, mem_high_water() as mem_high_water;`);
                var memUsed = rows[0]['mem_used'];
                var memHighWater = rows[0]['mem_high_water'];
                return {userID: savedUserID, memUsed: memUsed, memHighWater: memHighWater};
            }

            var savedStats = getMemStats();
            for (var i = 0; i < 100000; i++)
            {
                var newID = shortid();
                db.run.sync(db, `select var('currentUserID', '${newID}');`);
                //db.run.sync(db, `select var('currentUserID');`);
            }
            var newStats = getMemStats();
            db.run.sync(db, `select var('currentUserID', ?);`, savedStats.userID);
            db.close();
            db = helper.openMemoryDB();
            done();
        });
    });
});

describe('SQLite extensions: hash', ()=>
{
});

describe('SQLite extensions: eval', ()=>
{
});

describe('SQLite extensions: fileio', ()=>
{
});

describe('SQLite extensions: regexp', ()=>
{
});