/**
 * Created by slanska on 2016-03-04.
 */
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports", 'path'], factory);
    }
})(function (require, exports) {
    /// <reference path="../../typings/tests.d.ts" />
    'use strict';
    var path = require('path');
    describe('Reverse Engineering for existing SQLite databases', function () {
        beforeEach(function (done) {
            done();
        });
        it('Generate schema for Northwind database', function (done) {
            var srcDBName = path.join(__dirname, './data/northwind.db3');
            // reverseEngineering(srcDBName, done);
        });
        it('Generate schema for Chinook database', function (done) {
            var srcDBName = path.join(__dirname, './data/chinook.db');
            // reverseEngineering(srcDBName, done);
        });
    });
});
//# sourceMappingURL=reverseEng.spec.js.map