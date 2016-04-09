/**
 * Created by slanska on 2016-04-08.
 */


/// <reference path="../typings/tests.d.ts"/>

var Sync = require('syncho');
import helper = require('./helper');
import sqlite3 = require('sqlite3');
import faker = require('faker');
import chai = require('chai');
var shortid = require('shortid');

var expect = chai.expect;

describe('SQLite extensions: Flexilite EAV', ()=>
{
    var db:sqlite3.Database;

    before((done)=>
    {
        Sync(()=>
        {
            db = helper.openMemoryDB();
            done();
        });
    });

    after((done)=>
    {
        Sync(()=>
        {
            db.close.sync(db);
            done();
        });
    });

    it('basic flow', (done)=>
    {
        Sync(()=>
        {
            db.exec.sync(db, `create virtual table Person using 'flexi_eav' (
            FirstName text,
    LastName text,
    Gender char,
    AddressLine1 text,
    City text,
    StateOrProvince text,
    Country text,
    ZipOrPostalCode text,
    Email text,
    Phone text
        );`);

            var rows = db.all.sync(db, `select * from Person where LastName = 'Doe';`);
        });
    });
});