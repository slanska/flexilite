/**
 * Created by slanska on 2016-03-04.
 */


/// <reference path="../typings/mocha/mocha.d.ts"/>
/// <reference path="../typings/node/node.d.ts"/>
/// <reference path="../typings/chai/chai.d.ts" />
/// <reference path="../node_modules/orm/lib/TypeScript/orm.d.ts" />
/// <reference path="../typings/tsd.d.ts" />

import revEng = require('../lib/misc/reverseEng');
import mocha = require('mocha');

describe('Reverse Engineering for existing SQLite databases', () =>
{
    describe('Generate schema for Northwind database', ()=>
    {
        var re = new revEng('/Users/ruslanskorynin/flexilite/tests/data/northwind.db');
        var schema = re.loadSchemaFromDatabase();
        console.log(schema);
    })
});