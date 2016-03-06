// tests will go here

/// <reference path="../typings/mocha/mocha.d.ts"/>
/// <reference path="../typings/node/node.d.ts"/>
/// <reference path="../typings/chai/chai.d.ts" />
/// <reference path="../node_modules/orm/lib/TypeScript/orm.d.ts" />
/// <reference path="../typings/tsd.d.ts" />

'use strict';

import orm = require("orm");
var sqlite3 = require("sqlite3");
import util = require("util");
import path =require("path");
import helper = require("./helper");
var fs = require('fs');
var Sync = require("syncho");
import faker = require('faker');
var orm_trn = require('orm-transaction');
var Driver = require('../lib/FlexiliteAdapter').Driver;

var drv = require('../lib/drivers/SQLite/Driver');

/**
 * Unit tests
 */
// describe('Create new empty database:',
//     () =>
//     {
//         console.log('Create new DB\n');
//         console.log(drv);
//
//         beforeEach(
//             function (done)
//             {
//                 done();
//
//             });
//
//         describe('open sqlite db', () =>
//         {
//             //it('create DB', (done) =>
//             //{
//             //    Sync(function ()
//             //    {
//             //        var dbFile = path.join(__dirname, "data", "test1.db");
//             //        var db = new sqlite3.Database(dbFile, sqlite3.OPEN_CREATE | sqlite3.OPEN_READWRITE);
//             //        var qry = fs.readFile.sync(null, '/Users/ruslanskorynin/flexilite/lib/sqlite-schema.sql').toString();
//             //        db.exec.sync(db, qry);
//             //        db.close.sync(db);
//             //        done();
//             //    });
//             //
//             //});
//
//             it('opens', (done) =>
//             {
//                 done();
//                 return;
//
//                 helper.ConnectAndSave(done);
//                 //done();
//             });
//
//             it('generate 10000 persons', (done)=>
//             {
//                 done();
//                 return;
//
//                 Sync(function ()
//                 {
//                     // Use URI file name with shared cache mode
//                     var fname = `${path.join(__dirname, "data", "test1.db")}`;
//                     var connString = util.format("flexilite://%s", fname);
//                     var db = (<any>orm.connect).sync(orm, connString);
//                     db.use(orm_trn);
//
//                     console.log('DB opened\n');
//                     var Person = db.define("person", {
//
//                         name: String,
//                         surname: String,
//                         age: {type: "integer", unique: false, ui: {view: "text", width: "150"}, ext: {mappedTo: "C"}},
//                         male: {type: "boolean"},
//                         continent: ["Europe", "America", "Asia", "Africa", "Australia", "Antartica"], // ENUM type
//                         photo: Buffer,
//                         data: Object // JSON encoded
//                     }, {
//                         methods: {
//                             fullName: function ()
//                             {
//                                 return this.name + ' ' + this.surname;
//                             }
//                         }
//                     });
//
//                     var Car = db.define('car', {
//                         name: String,
//                         model: String,
//                         plateNumber: String,
//                         color: String,
//                         purchaseDate: Date,
//                         picture: Buffer
//                     });
//
//                     /*
//                      getCar
//                      hasCar
//                      removeCar
//
//                      == reverse:
//                      getOwners
//                      setOwners
//                      */
//                     Person.hasOne('favoriteCar', Car, {reverse: 'owner'});
//                     /*
//
//                      */
//                     Person.hasMany('cars', Car, {}, { reverse: 'person', key: true });
//
//
//                     console.time('insert Persons');
//
//                     var trn = db.transaction.sync(db);
//                     try
//                     {
//                         for (var idx = 0; idx < 10000; idx++)
//                         {
//                             Person.create.sync(Person, {
//                                 name: faker.name.firstName(1),
//                                 surname: faker.name.lastName(1),
//                                 age: faker.random.number({min: 15, max: 60}),
//                                 data: {City: faker.address.city(), Street: faker.address.streetName()},
//                                 extInfo: {age: faker.random.number(75) + 5, profession: faker.commerce.department()}
//                             });
//                         }
//
//                         trn.commit();
//                     }
//                     catch (err)
//                     {
//                         trn.rollback();
//                         throw err;
//                     }
//                     finally
//                     {
//                         db.close.sync(db);
//                         done();
//                     }
//                     console.timeEnd('insert Persons');
//                 });
//             });
//         });
//
//
//     });
//
