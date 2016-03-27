/**
 * Created by slanska on 2016-03-27.
 */
"use strict";
/// <reference path="../typings/mocha/mocha.d.ts"/>
// / <reference path="../typings/node/node.d.ts"/>
// / <reference path="../typings/chai/chai.d.ts" />
/// <reference path="../typings/tsd.d.ts" />
/// <reference path="../node_modules/orm/lib/TypeScript/orm.d.ts"/>
/// <reference path="../node_modules/orm/lib/TypeScript/sql-query.d.ts"/>
var Sync = require('syncho');
var helper = require('./helper');
var path = require('path');
var _ = require('lodash');
var chai = require('chai');
var shortid = require('shortid');
var ReverseEngine = require('../lib/misc/reverseEng');
var SchemaConverter = require('../lib/misc/schemaConverter');
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
                var conv = new SchemaConverter(db, item);
                conv.convert();
                console.log(conv.targetSchema);
            });
            done();
        });
    });
});
//# sourceMappingURL=schema_processing.js.map