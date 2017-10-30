/**
 * Created by Ruslan Skorynin on 04.10.2015.
 */

/// <reference path="../../typings/tests.d.ts" />
///<reference path="../typings/api.d.ts"/>

'use strict';

import chai = require('chai');

// TODO var expect = chai.expect;
//var Driver = require('../lib/FlexiliteAdapter').Driver;

// import orm = require("orm");
import sqlite3 = require('../dbhelper');
import util = require("util");
import path =require("path");

let shortid = require("shortid");
import faker = require("faker");
import fs = require('fs');
import Promise = require('bluebird');

/*
 Opens and initializes SQLite :memory: database.
 Expected to be run in the context of syncho
 Returns instance of database object
 */
export function openMemoryDB(): Promise<sqlite3.Database> {
    let result = new sqlite3.Database(':memory:');
    return initOpenedDB(result);
}

function initOpenedDB(db: sqlite3.Database): Promise<sqlite3.Database> {
    console.log(`Process ID=${process.pid}`);
    // let libPath = path.join(__dirname, '../../bin/libFlexilite');
    let libPath = '../../bin/libFlexilite';
    let currentUserID: any;
    return db.allAsync(`select randomblob(16) as uuid;`)
        .then((rows) => {
            currentUserID = rows[0]['uuid'];
            let sqlScript = fs.readFileSync(path.join(__dirname, '../lib/drivers/SQLite/dbschema.sql'), 'UTF-8');
            return db.execAsync(sqlScript);
        })
        .then(() => db.loadExtensionAsync(libPath))
        .then(() => {
            (db as any)["CurrentUserID"] = currentUserID;
            return db.runAsync(`select var('CurrentUserID', ?);`, currentUserID);
        });
}

/*
 Opens and initializes SQLite :memory: database.
 Expected to be run in the context of syncho
 Returns instance of database object
 */
export function openDB(dbFileName: string): Promise<sqlite3.Database> {
    let fname = path.join(__dirname, "data", dbFileName);
    let result = new sqlite3.Database(fname, sqlite3.OPEN_CREATE | sqlite3.OPEN_READWRITE);
    return initOpenedDB(result);
}