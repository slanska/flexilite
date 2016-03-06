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
require('../lib/drivers/SQLite');
var Sync = require('syncho');
describe('Typical scenarios of data refactoring', function () {
    it('1. Create', function (done) {
        done();
    });
    it('2. Name -> FirstName + LastName', function (done) {
        done();
    });
    it('3. Add Email and Phone', function (done) {
        done();
    });
    it('4. Extract Address into separate entity', function (done) {
        done();
    });
    it('5. Multiple emails and phones', function (done) {
        done();
    });
    it('6. Multiple addresses', function (done) {
        done();
    });
});
//# sourceMappingURL=personRefactoring.spec.js.map