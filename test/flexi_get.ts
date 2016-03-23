///<reference path="typings/tsd.d.ts"/>

import mocha = require('mocha');
import sqlite3 = require('sqlite3');
var syncho = require('syncho');
import path = require('path');
import fs = require('fs');
import faker = require('faker');

describe('flexi_get', ()=> {
    var db:sqlite3.Database;

    interface person1 {
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

    before((done) => {
        syncho(()=> {
            var libName = path.join(__dirname, '../bin/libsqlite_extensions.dylib');
            sqlite3.verbose();
            db = new sqlite3.Database(':memory:');
            (db as any).loadExtension.sync(db, libName);
            var sqlScript = fs.readFileSync('./dbschema.sql', 'UTF-8');
            db.exec.sync(db, sqlScript);

            done();
        });
    });

    beforeEach((done)=> {
        syncho(()=> {
            // var libName = path.join(__dirname, '../bin/libsqlite_extensions.dylib');
            // sqlite3.verbose();
            // db = new sqlite3.Database(':memory');
            // (db as any).loadExtension.sync(db, libName);
            done();
        });
    });

    it('Direct JSON', (done)=> {
        syncho(()=> {
            var json = JSON.stringify({abc: {xyz: ['Future will be ours', 'Crudbit Is Coming!']}});
            var rows = db.all.sync(db, `select typeof(Data), Data from (select flexi_get(11, 1001, json('{"properties":{"11":{"map":{"jsonPath": "$.abc.xyz[1]"}}}}'),
json('${json}')) as Data);`);
            console.log(rows);
            done();
        });
    });

    it('Person 1', (done)=> {
        // db.exec();
        //faker.
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

        // TODO insert into .collections
        // TODO Insert into .schemas
        db.run.sync(db, `insert into [.schemas] () values (?)`);
        db.run.sync(db, `insert into [.objects] (Data, SchemaID, CollectionID) values (?, ?, ?)`, JSON.stringify(p), 1, 1);

        done();
    });
});
