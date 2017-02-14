/**
 * Created by Ruslan Skorynin on 04.10.2015.
 */
/// <reference path="../../typings/tests.d.ts" />
///<reference path="../typings/api.d.ts"/>
'use strict';
// TODO var expect = chai.expect;
//var Driver = require('../lib/FlexiliteAdapter').Driver;
// import orm = require("orm");
var sqlite3 = require('../dbhelper');
var path = require("path");
var shortid = require("shortid");
var fs = require('fs');
/*
 Opens and initializes SQLite :memory: database.
 Expected to be run in the context of syncho
 Returns instance of database object
 */
function openMemoryDB() {
    var result = new sqlite3.Database(':memory:');
    return initOpenedDB(result);
}
exports.openMemoryDB = openMemoryDB;
function initOpenedDB(db) {
    console.log("Process ID=" + process.pid);
    // let libPath = path.join(__dirname, '../../bin/libFlexilite');
    var libPath = '../../bin/libFlexilite';
    var currentUserID;
    return db.allAsync("select randomblob(16) as uuid;")
        .then(function (rows) {
        currentUserID = rows[0]['uuid'];
        var sqlScript = fs.readFileSync(path.join(__dirname, '../lib/drivers/SQLite/dbschema.sql'), 'UTF-8');
        return db.execAsync(sqlScript);
    })
        .then(function () { return db.loadExtensionAsync(libPath); })
        .then(function () {
        db["CurrentUserID"] = currentUserID;
        return db.runAsync("select var('CurrentUserID', ?);", currentUserID);
    });
}
/*
 Opens and initializes SQLite :memory: database.
 Expected to be run in the context of syncho
 Returns instance of database object
 */
function openDB(dbFileName) {
    var fname = path.join(__dirname, "data", dbFileName);
    var result = new sqlite3.Database(fname, sqlite3.OPEN_CREATE | sqlite3.OPEN_READWRITE);
    return initOpenedDB(result);
}
exports.openDB = openDB;
//# sourceMappingURL=helper.js.map