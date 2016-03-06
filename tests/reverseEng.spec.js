/**
 * Created by slanska on 2016-03-04.
 */
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports", 'path', "orm", 'lodash'], factory);
    }
})(function (require, exports) {
    /// <reference path="../typings/mocha/mocha.d.ts"/>
    /// <reference path="../typings/node/node.d.ts"/>
    /// <reference path="../typings/chai/chai.d.ts" />
    /// <reference path="../node_modules/orm/lib/TypeScript/orm.d.ts" />
    /// <reference path="../typings/tsd.d.ts" />
    'use strict';
    var Flexilite = require('../lib/misc/reverseEng');
    require('../lib/drivers/SQLite');
    var path = require('path');
    var orm = require("orm");
    var Sync = require('syncho');
    var _ = require('lodash');
    describe('Reverse Engineering for existing SQLite databases', function () {
        it('Generate schema for Northwind database', function (done) {
            Sync(function () {
                var srcDBName = path.join(__dirname, './data/northwind.db');
                var re = new Flexilite.ReverseEngine(srcDBName);
                var schema = re.loadSchemaFromDatabase.sync(re);
                var destDBName = "" + path.join(__dirname, "data", "json_flexi.db");
                var connString = "flexilite://" + destDBName;
                var db = orm.connect.sync(orm, connString);
                _.forEach(schema, function (model, name) {
                    var props = re.getPropertiesFromORMDriverSchema(model);
                    var dataClass = db.define(name, props);
                    db.sync.sync(db);
                    // Define relations
                    console.log(name, model);
                });
                done();
            });
        });
    });
});
//# sourceMappingURL=reverseEng.spec.js.map