/**
 * Created by slanska on 2016-03-06.
 */

/// <reference path="../typings/mocha/mocha.d.ts"/>
/// <reference path="../typings/node/node.d.ts"/>
/// <reference path="../typings/chai/chai.d.ts" />
/// <reference path="../node_modules/orm/lib/TypeScript/orm.d.ts" />
/// <reference path="../typings/tsd.d.ts" />

'use strict';

var Flexilite = require('../lib/misc/reverseEng');
import mocha = require('mocha');
require('../lib/drivers/SQLite');
import path = require('path');
import orm = require("orm");
var Sync = require('syncho');
import _ = require('lodash');

describe('Typical scenarios of data refactoring', () =>
{
    it('1. Create', (done)=>
    {
        done();
    });

    it('2. Name -> FirstName + LastName', (done)=>
    {
        done();
    });

    it('3. Add Email and Phone', (done)=>
    {
        done();
    });

    it('4. Extract Address into separate entity', (done)=>
    {
        done();
    });

    it('5. Multiple emails and phones', (done)=>
    {
        done();
    });

    it('6. Multiple addresses', (done)=>
    {
        done();
    });
});