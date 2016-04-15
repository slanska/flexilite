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

    var personMeta = {
        properties: {
            FirstName: {rules: {type: PROPERTY_TYPE.TEXT, minOccurences: 1, maxOccurences: 1}},
            LastName: {rules: {type: PROPERTY_TYPE.TEXT}},
            Gender: {rules: {type: PROPERTY_TYPE.ENUM}},
            AddressLine1: {rules: {type: PROPERTY_TYPE.TEXT}},
            City: {rules: {type: PROPERTY_TYPE.TEXT}},
            StateOrProvince: {rules: {type: PROPERTY_TYPE.TEXT}},
            Country: {rules: {type: PROPERTY_TYPE.TEXT}},
            ZipOrPostalCode: {rules: {type: PROPERTY_TYPE.TEXT}},
            Email: {rules: {type: PROPERTY_TYPE.TEXT}},
            Phone: {rules: {type: PROPERTY_TYPE.TEXT}}
        }
    } as IClassDefinition;

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
            let def = JSON.stringify(personMeta);
            db.exec.sync(db, `create virtual table Person using 'flexi_eav' ('${def}');`);

            var rows = db.all.sync(db, `select * from Person where LastName = 'Doe';`);
        });
    });
});