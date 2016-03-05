/**
 * Created by slanska on 2016-03-04.
 */
"use strict";
/// <reference path="../typings/mocha/mocha.d.ts"/>
/// <reference path="../typings/node/node.d.ts"/>
/// <reference path="../typings/chai/chai.d.ts" />
/// <reference path="../node_modules/orm/lib/TypeScript/orm.d.ts" />
/// <reference path="../typings/tsd.d.ts" />
var revEng = require('../lib/misc/reverseEng');
describe('Reverse Engineering for existing SQLite databases', function () {
    describe('Generate schema for Northwind database', function () {
        var re = new revEng('/Users/ruslanskorynin/flexilite/tests/data/northwind.db');
        var schema = re.loadSchemaFromDatabase();
        console.log(schema);
    });
});
//# sourceMappingURL=reverseEng.spec.js.map