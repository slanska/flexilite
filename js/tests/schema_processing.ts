/**
 * Created by slanska on 2016-03-27.
 */

/// <reference path="../typings/tests.d.ts"/>

var Sync = require('syncho');
import helper = require('./helper');
import path = require('path');
import sqlite3 = require('sqlite3');
import faker = require('faker');
import _ = require('lodash');
import chai = require('chai');
var shortid = require('shortid');
import {ReverseEngine} from '../flexish/reverseEng';
import {SchemaHelper} from '../lib/misc/SchemaHelper';

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
            var db = new sqlite3.Database(dbPath);
            var revEng = new ReverseEngine(db);
            var schema = revEng.parseSQLiteSchema.sync(revEng);

            _.forEach(schema, (item:ISyncOptions, className:string)=>
            {
                let conv = new SchemaHelper(db, item, null);
                conv.convertFromNodeOrmSync();
                console.log(conv.targetClassProps);
            });

            done();
        });
    });
});