/**
 * Created by slanska on 2016-03-04.
 */

/// <reference path="../../typings/tests.d.ts" />

'use strict';

import mocha = require('mocha');
import path = require('path');
import _ = require('lodash');

describe('Reverse Engineering for existing SQLite databases', () => {
    beforeEach((done: Function) => {
        done();
    });

    it('Generate schema for Northwind database', (done: Function) => {
        var srcDBName = path.join(__dirname, './data/northwind.db3');
        // reverseEngineering(srcDBName, done);

    });

    it('Generate schema for Chinook database', (done: Function) => {
        var srcDBName = path.join(__dirname, './data/chinook.db');
        // reverseEngineering(srcDBName, done);
    });
});