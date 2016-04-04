/**
 * Created by slanska on 2016-03-27.
 */
"use strict";
/// <reference path="../typings/tests.d.ts"/>
var Sync = require('syncho');
var helper = require('./helper');
var path = require('path');
var _ = require('lodash');
var chai = require('chai');
var shortid = require('shortid');
var ReverseEngine = require('../lib/misc/reverseEng');
var SchemaHelper = require('../lib/misc/SchemaHelper');
var expect = chai.expect;
describe('Flexilite schema processing', function () {
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
    it('converts node-orm schema to Flexilite schema', function (done) {
        Sync(function () {
            var dbPath = path.join(__dirname, "data", "chinook.db");
            var revEng = new ReverseEngine(dbPath);
            var schema = revEng.loadSchemaFromDatabase.sync(revEng);
            _.forEach(schema, function (item, className) {
                var conv = new SchemaHelper(db, item);
                conv.convertFromNodeOrmSync();
                console.log(conv.targetSchema);
            });
            done();
        });
    });
});
//# sourceMappingURL=schema_processing.js.map