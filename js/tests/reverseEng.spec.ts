/**
 * Created by slanska on 2016-03-04.
 */

/// <reference path="../typings/tests.d.ts" />

'use strict';

var ReverseEngine = require('../flexish/reverseEng');
import mocha = require('mocha');
require('../lib/drivers/SQLite');
import path = require('path');
import orm = require("orm");
var Sync = require('syncho');
import _ = require('lodash');

describe('Reverse Engineering for existing SQLite databases', () =>
{
    beforeEach((done)=>
    {
        done();
    });

    function reverseEngineering(srcDBName:string, done)
    {
        Sync(()=>
        {
            var re = new ReverseEngine(srcDBName);
            var schema = re.parseSQLiteSchema.sync(re);

            var destDBName = `${path.join(__dirname, "data", "json_flexi.db")}`;
            var connString = `flexilite://${destDBName}`;
            var db = orm.connect.sync<orm.ORM>(orm, connString);
            _.forEach(schema, (model:ISyncOptions, name:string) =>
            {
                var props = re.getPropertiesFromORMDriverSchema(model);
                var dataClass = db.define(name, props);
                db.sync.sync(db);

                // TODO Define relations

                console.log(name, model);
            });

            done();
        });
    }

    it('Generate schema for Northwind database', (done)=>
    {
        var srcDBName = path.join(__dirname, './data/northwind.db3');
        reverseEngineering(srcDBName, done);

    });

    it('Generate schema for Chinook database', (done)=>
    {
        var srcDBName = path.join(__dirname, './data/chinook.db');
        reverseEngineering(srcDBName, done);
    });
});