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

/**
 * Unit tests
 */
describe(' Create new empty database:',
    () =>
    {
        console.log('Create new DB\n');

        //sqlite.cached.Database();

        beforeEach(
            function ()
            {
            });

        describe('open sqlite db', () =>
        {
            helper.ConnectAndSave();

            it('opens', (done) =>
            {

                done();
            });

        });
    });


