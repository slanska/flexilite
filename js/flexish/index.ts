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

let cli = require('cli');
import Promise = require('bluebird');
import sqlite = require('../dbhelper');
import path = require('path');
var jsBeautify = require('js-beautify');
import fs = require('fs');

import {SQLiteSchemaParser} from './sqliteSchemaParser';
import {runFlexiliteQuery} from './runQuery';
import {initFlexiliteDatabase} from './initDb';

// Promise.promisify(sqlite.Database.prototype.all);
// Promise.promisify(sqlite.Database.prototype.exec);
// Promise.promisify(sqlite.Database.prototype.run);

const usage = "command <param> -options" +
    "";

cli.setApp('Flexilite Shell Utility', '0.0.1');
cli.setUsage(usage);
cli.no_color = false;
cli.enable('status', 'version', 'catchall');

cli.parse(
    // Switches
    {
        output: ['o', 'Output file name', 'file'],
        config: ['c', 'Path to config file', 'file'],
        query: ['q', 'Path to query file', 'as-is'],
        database: ['d', 'Path to SQLite database file', 'file']
    },

    // Commands
    ['schema', 'load', 'query', 'help', 'init']);

function generateSchema(args, options) {
    let db = new sqlite.Database(options.database);
    let parser = new SQLiteSchemaParser(db);
    return parser.parseSchema()
        .then((schema) => {
            let out = jsBeautify(schema);

            // let fileName = path.join(path.dirname(options.database), path.);
            // fs.writeFileSync(fileName, out);
            return 0;
        });
}

function queryDatabase(args, options) {
    // Init db
    // return runFlexiliteQuery();
}

function loadData(args, options) {
}

function initDatabase(args, options) {
}

/*
 Main function will get list of free standing arguments (not commands)
 and hash of named options
 */
cli.main((args, options) => {
    switch (cli.command) {
        case 'schema':
            if (!options.database)
                options.database = args[0];

            generateSchema(args, options)
                .then((exitCode: number) => {
                    process.exit(exitCode);
                });
            break;

        case 'query':
            if (options.query) {

            }
            else {
            }
            break;

        case 'load':
            break;

        case 'help':
            cli.getUsage();
            cli.exit(0);
            break;
    }

});

//
// cli.info('Info');
// cli.error('Error');
// cli.ok('OK');
// console.warn('Like this');
// cli.status('Status', 'debug');
// console.log('Command is: ' + cli.command);
// cli.spinner('Working..');
// setTimeout(() => {
//     cli.spinner('Done!', true);
//     process.exit(0);
// }, 2000);
//
