/**
 * Created by slanska on 2016-03-25.
 */
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports", './helper', 'faker', 'chai'], factory);
    }
})(function (require, exports) {
    "use strict";
    /// <reference path="../typings/tests.d.ts"/>
    var Sync = require('syncho');
    var helper = require('./helper');
    var faker = require('faker');
    var chai = require('chai');
    var shortid = require('shortid');
    var expect = chai.expect;
    describe('SQLite extensions: flexi_get', function () {
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
        beforeEach(function (done) {
            var p = {
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
        it('Basic JSON: direct', function (done) {
            Sync(function () {
                var json = JSON.stringify({ abc: { xyz: ['Future will be ours', 'Crudbit Is Coming!'] } });
                var rows = db.all.sync(db, "select typeof(Data), Data from (select flexi_get(11, 1001, json('{\"properties\":{\"11\":{\"map\":{\"jsonPath\": \"$.abc.xyz[1]\"}}}}'),\njson('" + json + "')) as Data);");
                expect(rows[0]['Data']).to.be.equal('Crudbit Is Coming!');
                done();
            });
        });
        it('Basic JSON: nested attribute', function (done) {
            done();
        });
        it('Basic JSON: item in array', function (done) {
            done();
        });
        it('Basic JSON: item in nested array', function (done) {
            done();
        });
        it('Basic JSON: with default value', function (done) {
            done();
        });
        it('Basic JSON: with default value as null', function (done) {
            done();
        });
        it('Indirect JSON: first item in collection', function (done) {
            done();
        });
        it('Indirect JSON: last item in collection', function (done) {
            done();
        });
        it('Indirect JSON: filter first item', function (done) {
            done();
        });
        it('Indirect JSON: filter last item', function (done) {
            done();
        });
        it('Indirect JSON: sorted first item', function (done) {
            done();
        });
        it('Indirect JSON: sorted last item', function (done) {
            done();
        });
        it('Indirect JSON: filtered and sorted first item', function (done) {
            done();
        });
        it('Indirect JSON: filtered and sorted last item', function (done) {
            done();
        });
        it('Indirect JSON: by specific index in collection', function (done) {
            done();
        });
    });
    describe('SQLite extensions: var', function () {
        var db;
        before(function (done) {
            Sync(function () {
                db = helper.openMemoryDB();
                done();
            });
        });
        after(function (done) {
            Sync(function () {
                db.close();
                done();
            });
        });
        it('retrieves the same CurrentUserID', function (done) {
            Sync(function () {
                var rows = db.all.sync(db, "select var('currentuserid') as CurrentUserID");
                expect(rows[0]['CurrentUserID']).to.deep.equal(db['CurrentUserID']);
                done();
            });
        });
        it('does not have memory leaks', function (done) {
            Sync(function () {
                function getMemStats() {
                    var savedUserID = db['CurrentUserID'];
                    var rows = db.all.sync(db, "select mem_used() as mem_used, mem_high_water() as mem_high_water;");
                    var memUsed = rows[0]['mem_used'];
                    var memHighWater = rows[0]['mem_high_water'];
                    return { userID: savedUserID, memUsed: memUsed, memHighWater: memHighWater };
                }
                var savedStats = getMemStats();
                for (var i = 0; i < 100000; i++) {
                    var newID = shortid();
                    db.run.sync(db, "select var('currentUserID', '" + newID + "');");
                }
                var newStats = getMemStats();
                db.run.sync(db, "select var('currentUserID', ?);", savedStats.userID);
                db.close();
                db = helper.openMemoryDB();
                done();
            });
        });
    });
    describe('SQLite extensions: hash', function () {
        var db;
        before(function (done) {
            Sync(function () {
                db = helper.openMemoryDB();
                done();
            });
        });
        after(function (done) {
            Sync(function () {
                db.close();
                done();
            });
        });
        it('generates basic hash', function (done) {
            Sync(function () {
                var rows = db.all.sync(db, "select hash('Crudbit will win!') as hash;");
                var hash = rows[0].hash;
                console.log("Hash: " + hash);
                done();
            });
        });
    });
    describe('SQLite extensions: eval', function () {
    });
    describe('SQLite extensions: fileio', function () {
    });
    describe('SQLite extensions: regexp', function () {
    });
    describe('SQLite extensions: compress', function () {
    });
});
//# sourceMappingURL=flexi_get.js.map