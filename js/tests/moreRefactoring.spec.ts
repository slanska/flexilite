/**
 * Created by slanska on 2016-03-06.
 */

/// <reference path="../typings/mocha/mocha.d.ts"/>
/// <reference path="../typings/node/node.d.ts"/>
/// <reference path="../typings/chai/chai.d.ts" />
/// <reference path="../node_modules/orm/lib/TypeScript/orm.d.ts" />
/// <reference path="../typings/tsd.d.ts" />

'use strict';

var Flexilite = require('../flexish/reverseEng');
import mocha = require('mocha');
require('../lib/drivers/SQLite');
import path = require('path');
import orm = require("orm");
var Sync = require('syncho');
import _ = require('lodash');

describe('More data refactoring', () =>
{
    it('1. Move references in the list', (done)=>
    {
        done();
    });

    it('2. Indexed properties', (done)=>
    {
        done();
    });

    it('3. Delete property', (done)=>
    {
        done();
    });

    it('4. Delete class', (done)=>
    {
        done();
    });

    it('5. Embed referenced objects', (done)=>
    {
        done();
    });

    it('6. Computed property', (done)=>
    {
        done();
    });

    it('7. Create class from data', (done)=>
    {
        done();
    });

    it('8. Find matching class and schema for data', (done)=>
    {
        done();
    });
});