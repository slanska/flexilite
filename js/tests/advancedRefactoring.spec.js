/**
 * Created by slanska on 2016-03-06.
 */
/// <reference path="../../typings/mocha/mocha.d.ts"/>
/// <reference path="../../typings/node/node.d.ts"/>
/// <reference path="../../typings/chai/chai.d.ts" />
/// <reference path="../../typings/tsd.d.ts" />
'use strict';
require('../lib/drivers/SQLite');
describe('Advanced cases of data refactoring', function () {
    it('1. Merge objects', function (done) {
        done();
    });
    it('2. Split objects', function (done) {
        done();
    });
    it('3. Change class type (assign objects to a different class)', function (done) {
        done();
    });
    it('4. Rename class', function (done) {
        done();
    });
    it('5. Rename property', function (done) {
        done();
    });
    it('6. One-to-many -> many-to-many', function (done) {
        done();
    });
    /*
    Country text column -> Extract to separate object, replace with country ID -> include into row
    by auto-generated link to Countries
     */
    it('7. Scalar value(s) -> Extract to separate object -> Display value(s) from referenced object', function (done) {
        done();
    });
});
//# sourceMappingURL=advancedRefactoring.spec.js.map