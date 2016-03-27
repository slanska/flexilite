/**
 * Created by slanska on 2016-03-27.
 */

/// <reference path="../typings/mocha/mocha.d.ts"/>
// / <reference path="../typings/node/node.d.ts"/>
// / <reference path="../typings/chai/chai.d.ts" />
/// <reference path="../typings/tsd.d.ts" />
/// <reference path="../node_modules/orm/lib/TypeScript/orm.d.ts"/>
/// <reference path="../node_modules/orm/lib/TypeScript/sql-query.d.ts"/>

var Sync = require('syncho');
import helper = require('./helper');
import path = require('path');
import sqlite3 = require('sqlite3');
import faker = require('faker');
import _ = require('lodash');
import chai = require('chai');
var shortid = require('shortid');
import ReverseEngine = require( '../lib/misc/reverseEng');
import SchemaConverter = require('../lib/misc/schemaConverter');

var expect = chai.expect;

describe('Flexilite schema processing', ()=>
{
    var db:sqlite3.Database;

    before((done)=>
    {
        Sync(()=>
        {
            db = helper.openMemoryDB();
            done();
        });
    });

    after((done)=>
    {
        Sync(()=>
        {
            db.close.sync(db);
            done();
        });
    });

    it('converts node-orm schema to Flexilite schema', (done)=>
    {
        Sync(()=>
        {
            var dbPath = path.join(__dirname, "data", "chinook.db");
            var revEng = new ReverseEngine(dbPath);
            var schema = revEng.loadSchemaFromDatabase.sync(revEng);

            _.forEach(schema, (item:ISyncOptions, className:string)=>
            {
                let conv = new SchemaConverter(db, item);
                conv.convert();
                console.log(conv.targetSchema);
            });

            done();
        });
    });
});