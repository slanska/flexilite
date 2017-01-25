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

let commander = require('commander');
let colors = require('colors');

import {ReverseEngine} from '../lib/misc/reverseEng';

commander
    .version('0.0.1')
    .usage('[options] <file ...>')
    .command('load')
    .command('schema')
    .command('query')
    .option('-d', '--database', 'Path to SQLite database file')
    .option('-c', '--config', 'Path to config file')
    .option('-s', '--source', 'Source database connection string')
    .option('-o', '-output', 'Output file name')
    .parse(process.argv);
