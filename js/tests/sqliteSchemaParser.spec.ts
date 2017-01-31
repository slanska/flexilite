/**
 * Created by slanska on 2017-01-30.
 */

/// <reference path="../../typings/tests.d.ts" />

import sqlite = require('sqlite3');
import {parseSQLiteSchema} from '../flexish/sqliteSchemaParser';
import path = require('path');
import Promise =require( 'bluebird');

sqlite.Database.prototype['allAsync'] = Promise.promisify(sqlite.Database.prototype.all) as any;
// Promise.promisify(sqlite.Database.prototype.exec);
// Promise.promisify(sqlite.Database.prototype.run);

describe('Parse SQLite schema and generate Flexilite model', () => {
    beforeEach((done) => {
        done();
    });

    it('Generate schema from Northwind DB', (done) => {
        let dbPath = path.resolve(__dirname, '../../data/Northwind.db3');
        let db = new sqlite.Database(dbPath, sqlite.OPEN_CREATE | sqlite.OPEN_READWRITE);
        parseSQLiteSchema(db).then(model => {
            done();
        });
    });


    afterEach((done) => {
        done();
    });
});