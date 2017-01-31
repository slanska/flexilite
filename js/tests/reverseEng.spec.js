/**
 * Created by slanska on 2016-03-04.
 */
/// <reference path="../typings/tests.d.ts" />
'use strict';
var ReverseEngine = require('../flexish/reverseEng');
require('../lib/drivers/SQLite');
var path = require('path');
var orm = require("orm");
var Sync = require('syncho');
var _ = require('lodash');
describe('Reverse Engineering for existing SQLite databases', function () {
    beforeEach(function (done) {
        done();
    });
    function reverseEngineering(srcDBName, done) {
        Sync(function () {
            var re = new ReverseEngine(srcDBName);
            var schema = re.parseSQLiteSchema.sync(re);
            var destDBName = "" + path.join(__dirname, "data", "json_flexi.db");
            var connString = "flexilite://" + destDBName;
            var db = orm.connect.sync(orm, connString);
            _.forEach(schema, function (model, name) {
                var props = re.getPropertiesFromORMDriverSchema(model);
                var dataClass = db.define(name, props);
                db.sync.sync(db);
                // TODO Define relations
                console.log(name, model);
            });
            done();
        });
    }
    it('Generate schema for Northwind database', function (done) {
        var srcDBName = path.join(__dirname, './data/northwind.db3');
        reverseEngineering(srcDBName, done);
    });
    it('Generate schema for Chinook database', function (done) {
        var srcDBName = path.join(__dirname, './data/chinook.db');
        reverseEngineering(srcDBName, done);
    });
});
//# sourceMappingURL=reverseEng.spec.js.map