/**
 * Created by slanska on 2017-01-24.
 */

/*
 Main module for flexish (FLEXI-lite SH-ell) - utility for basic operations
 Supported commands:
 * load - loads data from external source into given Flexilite database
 * query - uses passed JSON query to extract data
 * schema - generates JSON schema from existing SQLite database
 */

/// <reference path="../../typings/tsd.d.ts"/>

/*
 Helper utility for auxiliary tasks with Flexilite database
 * Generate JSON schema from existing SQLite database
 * Create or modify classes based on JSON schema
 * Execute query in JSON format (from external file or command line or console input)
 * Load data from external database (via Knex.js driver) to Flexilite database
 * Output schema from Flexilite database
 * Output statistics on Flexilite usage
 */

///<reference path="../../typings/index.d.ts"/>

let commander = require('commander');
let colors = require('colors');
import Promise = require('bluebird');
import sqlite = require('sqlite3');

import {parseSQLiteSchema} from './sqliteSchemaParser';
import {runFlexiliteQuery} from './runQuery';
import {initFlexiliteDatabase} from './initDb';

Promise.promisify(sqlite.Database.prototype.all);
Promise.promisify(sqlite.Database.prototype.exec);
Promise.promisify(sqlite.Database.prototype.run);

const usage = "[options] <file ...>";

commander
    .version('0.0.1')
    .usage(usage)
    .command('load')
    .command('schema')
    .command('query')
    .command('init')
    .command('help')
    .option('-d', '--database', 'Path to SQLite database file')
    .option('-c', '--config', 'Path to config file')
    .option('-s', '--source', 'Source database connection string')
    .option('-o', '-output', 'Output file name')
    .option('-f', '-fkey', 'Process foreign keys')
    .option('-m', '-many2many', 'Make guesses about many to many relationship')
    .parse(process.argv);

console.log(commander);
// commander.

//var parser = new SQLiteSchemaParser();