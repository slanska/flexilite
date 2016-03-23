///<reference path="typings/tsd.d.ts"/>
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports", 'sqlite3', 'path', 'fs', 'faker'], factory);
    }
})(function (require, exports) {
    "use strict";
    var sqlite3 = require('sqlite3');
    var syncho = require('syncho');
    var path = require('path');
    var fs = require('fs');
    var faker = require('faker');
    describe('flexi_get', function () {
        var db;
        before(function (done) {
            syncho(function () {
                var libName = path.join(__dirname, '../bin/libsqlite_extensions.dylib');
                sqlite3.verbose();
                db = new sqlite3.Database(':memory:');
                db.loadExtension.sync(db, libName);
                var sqlScript = fs.readFileSync('./dbschema.sql', 'UTF-8');
                db.exec.sync(db, sqlScript);
                done();
            });
        });
        beforeEach(function (done) {
            syncho(function () {
                // var libName = path.join(__dirname, '../bin/libsqlite_extensions.dylib');
                // sqlite3.verbose();
                // db = new sqlite3.Database(':memory');
                // (db as any).loadExtension.sync(db, libName);
                done();
            });
        });
        it('Direct JSON', function (done) {
            syncho(function () {
                var json = JSON.stringify({ abc: { xyz: ['Future will be ours', 'Crudbit Is Coming!'] } });
                var rows = db.all.sync(db, "select typeof(Data), Data from (select flexi_get(11, 1001, json('{\"properties\":{\"11\":{\"map\":{\"jsonPath\": \"$.abc.xyz[1]\"}}}}'),\njson('" + json + "')) as Data);");
                console.log(rows);
                done();
            });
        });
        it('Person 1', function (done) {
            // db.exec();
            //faker.
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
            // TODO insert into .collections
            // TODO Insert into .schemas
            db.run.sync(db, "insert into [.schemas] () values (?)");
            db.run.sync(db, "insert into [.objects] (Data, SchemaID, CollectionID) values (?, ?, ?)", JSON.stringify(p), 1, 1);
            done();
        });
    });
});
//# sourceMappingURL=flexi_get.js.map