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
/**
 * Unit tests
 */
describe(' Create new empty database:', function () {
    console.log('Create new DB\n');
    //sqlite.cached.Database();
    beforeEach(function () {
    });
    describe('open sqlite db', function () {
        helper.ConnectAndSave();
        it('opens', function (done) {
            done();
        });
    });
});
