///<reference path="typings/tsd.d.ts"/>
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports", 'sqlite3', 'path'], factory);
    }
})(function (require, exports) {
    "use strict";
    var sqlite3 = require('sqlite3');
    var syncho = require('syncho');
    var path = require('path');
    describe('flexi_get', function () {
        var db;
        beforeEach(function (done) {
            syncho(function () {
                var libName = path.join(__dirname, '../bin/libsqlite_extensions.dylib');
                sqlite3.verbose();
                db = new sqlite3.Database(':memory');
                db.loadExtension.sync(db, libName);
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
    });
});
//# sourceMappingURL=flexi_get.js.map