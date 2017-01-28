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

describe('Advanced cases of data refactoring', () =>
{
    it('1. Merge objects', (done)=>
    {
        done();
    });

    it('2. Split objects', (done)=>
    {
        done();
    });

    it('3. Change class type (assign objects to a different class)', (done)=>
    {
        done();
    });

    it('4. Rename class', (done)=>
    {
        done();
    });

    it('5. Rename property', (done)=>
    {
        done();
    });

    it('6. One-to-many -> many-to-many', (done)=>
    {
        done();
    });

    /*
    Country text column -> Extract to separate object, replace with country ID -> include into row
    by auto-generated link to Countries
     */
    it('7. Scalar value(s) -> Extract to separate object -> Display value(s) from referenced object', (done)=>
    {
        done();
    });
});