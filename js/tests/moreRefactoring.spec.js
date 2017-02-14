/**
 * Created by slanska on 2016-03-06.
 */
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports"], factory);
    }
})(function (require, exports) {
    /// <reference path="../../typings/mocha/mocha.d.ts"/>
    /// <reference path="../../typings/node/node.d.ts"/>
    /// <reference path="../../typings/chai/chai.d.ts" />
    /// <reference path="../../typings/tsd.d.ts" />
    'use strict';
    require('../lib/drivers/SQLite');
    describe('More data refactoring', function () {
        it('1. Move references in the list', function (done) {
            done();
        });
        it('2. Indexed properties', function (done) {
            done();
        });
        it('3. Delete property', function (done) {
            done();
        });
        it('4. Delete class', function (done) {
            done();
        });
        it('5. Embed referenced objects', function (done) {
            done();
        });
        it('6. Computed property', function (done) {
            done();
        });
        it('7. Create class from data', function (done) {
            done();
        });
        it('8. Find matching class and schema for data', function (done) {
            done();
        });
    });
});
//# sourceMappingURL=moreRefactoring.spec.js.map