/**
 * Created by slanska on 2017-01-30.
 */

/// <reference path="../../typings/lib.d.ts" />
///<reference path="../typings/api.d.ts"/>
///<reference path="../typings/definitions.d.ts"/>

'use strict';

import sqlite = require('sqlite3');
import _ = require('lodash');
import Promise = require('bluebird');


/*
 Executes query on Flexilite database
 Query is specified in IFlexiliteQuery format
 Returns promise to IFlexiliteResponse
 */
export function runFlexiliteQuery(db:sqlite.Database, query) {

}