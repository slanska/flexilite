// tests will go here

/// <reference path="../typings/mocha/mocha.d.ts"/>
/// <reference path="../typings/node/node.d.ts"/>
/// <reference path="../typings/chai/chai.d.ts" />
/// <reference path="../node_modules/orm/lib/TypeScript/orm.d.ts" />

'use strict';

import chai = require('chai');

var expect = chai.expect;
var flexilite = require('../lib/FlexiliteAdapter');
import orm = require("orm");
var sqlite3 = require("sqlite3");
import util = require("util");
import path =require("path");
import helper = require("./helper");
var wait = require('wait.for');
var fs = require('fs');

//wait.launchFiber(function ()
//{
/**
 * Unit tests
 */
describe(' Create new empty database:',
    () =>
    {
        console.log('Create new DB\n');

        //sqlite.cached.Database();

        //before(function (done)
        //{
        //    wait.launchFiber(function ()
        //    {
        //        var db = wait.forMethod(sqlite3, "Database", path.join(__dirname, "data", "test1.db"));
        //        var qry = fs.readFileSync('../lib/sqlite-schema.sql');
        //        wait.forMethod(db, "run", qry);
        //    });
        //
        //    done();
        //});

        beforeEach(
            function (done)
            {
                console.log('beforeEach ---');
                //wait.launchFiber(function ()
                //{

                var dbFile = path.join(__dirname, "data", "test1.db");
                var db = new sqlite3.Database(dbFile);
                var qry = fs.readFileSync('/Users/ruslanskorynin/flexilite/lib/sqlite-schema.sql').toString();
                db.run(qry, function (err)
                {
                    if (err)
                        throw err;
                    done();
                });
                //done();
                //});


            });

        describe('open sqlite db', () =>
        {

            it('opens', (done) =>
            {
                //helper.ConnectAndSave(done);
                done();
            });

            //it('create model', (done) =>
            //{
            //    //helper.
            //    done();
            //});

        });


        //});
    });

