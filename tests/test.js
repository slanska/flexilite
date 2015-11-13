// tests will go here
/// <reference path="../typings/mocha/mocha.d.ts"/>
/// <reference path="../typings/node/node.d.ts"/>
/// <reference path="../typings/chai/chai.d.ts" />
/// <reference path="../node_modules/orm/lib/TypeScript/orm.d.ts" />
'use strict';
var chai = require('chai');
var expect = chai.expect;
var flexilite = require('../lib/FlexiliteAdapter');
var sqlite3 = require("sqlite3");
var helper = require("./helper");
var fs = require('fs');
var Sync = require("syncho");
/**
 * Unit tests
 */
describe(' Create new empty database:', function () {
    console.log('Create new DB\n');
    beforeEach(function (done) {
        done();
    });
    describe('open sqlite db', function () {
        //it('create DB', (done) =>
        //{
        //    Sync(function ()
        //    {
        //        var dbFile = path.join(__dirname, "data", "test1.db");
        //        var db = new sqlite3.Database(dbFile);
        //        var qry = fs.readFile.sync(null, '/Users/ruslanskorynin/flexilite/lib/sqlite-schema.sql').toString();
        //        db.exec.sync(db, qry);
        //        db.close.sync(db);
        //        done();
        //    });
        //
        //});
        it('opens', function (done) {
            helper.ConnectAndSave(done);
            //done();
        });
        //it('create model', (done) =>
        //{
        //    //helper.
        //    done();
        //});
    });
});
//# sourceMappingURL=test.js.map