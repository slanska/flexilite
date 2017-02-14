/**
 * Created by slanska on 2016-03-27.
 */

/// <reference path="../../typings/tests.d.ts"/>

import helper = require('./helper');
import path = require('path');
import sqlite3 = require('sqlite3');
import faker = require('faker');
import _ = require('lodash');
import chai = require('chai');

var expect = chai.expect;

describe('Flexilite schema processing', () => {
    var db: sqlite3.Database;

    before((done) => {
        helper.openMemoryDB()
            .then(d => {
                db = d;
                done();
            });
    });

    after((done) => {
        db.closeAsync()
            .then(() => done());
    });
});