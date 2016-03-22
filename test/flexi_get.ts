///<reference path="typings/tsd.d.ts"/>

import mocha = require('mocha');
import sqlite3 = require('sqlite3');
var syncho = require('syncho');
import path = require('path');

describe('flexi_get', ()=> {
    var db:sqlite3.Database;

    beforeEach((done)=> {
        syncho(()=> {
            var libName = path.join(__dirname, '../bin/libsqlite_extensions.dylib');
            sqlite3.verbose();
            db = new sqlite3.Database(':memory');
            (db as any).loadExtension.sync(db, libName);
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
});
