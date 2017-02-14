/**
 * Created by slanska on 2016-03-27.
 */
"use strict";
/// <reference path="../../typings/tests.d.ts"/>
var helper = require('./helper');
var chai = require('chai');
var expect = chai.expect;
describe('Flexilite schema processing', function () {
    var db;
    before(function (done) {
        helper.openMemoryDB()
            .then(function (d) {
            db = d;
            done();
        });
    });
    after(function (done) {
        db.closeAsync()
            .then(function () { return done(); });
    });
});
//# sourceMappingURL=schema_processing.js.map