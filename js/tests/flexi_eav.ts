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
            FirstName: {rules: {type: PROPERTY_TYPE.PROP_TYPE_TEXT, minOccurences: 1, maxOccurences: 1}},
            LastName: {rules: {type: PROPERTY_TYPE.PROP_TYPE_TEXT}},
            Gender: {rules: {type: PROPERTY_TYPE.PROP_TYPE_ENUM}}, // TODO items
            AddressLine1: {rules: {type: PROPERTY_TYPE.PROP_TYPE_TEXT}},
            City: {rules: {type: PROPERTY_TYPE.PROP_TYPE_TEXT}},
            StateOrProvince: {rules: {type: PROPERTY_TYPE.PROP_TYPE_TEXT}},
            Country: {rules: {type: PROPERTY_TYPE.PROP_TYPE_TEXT}},
            ZipOrPostalCode: {rules: {type: PROPERTY_TYPE.PROP_TYPE_TEXT}},
            Email: {rules: {type: PROPERTY_TYPE.PROP_TYPE_TEXT}},
            Phone: {rules: {type: PROPERTY_TYPE.PROP_TYPE_TEXT}}
        }
    } as IClassDefinition;

    function randomPersonArguments():any
    {
        let gender = faker.random.number(1);
        let result = {
            $FirstName: faker.name.firstName(gender),
            $LastName: faker.name.lastName(gender),
            $Gender: gender,
            $AddressLine1: faker.address.streetAddress(),
            $City: faker.address.city(),
            $StateOrProvince: faker.address.stateAbbr(),
            $Country: faker.address.country(),
            $ZipOrPostalCode: faker.address.zipCode(),
            $Email: faker.internet.email(),
            $Phone: faker.phone.phoneNumber()
        };
        return result;
    }

    before((done)=>
    {
        Sync(()=>
        {
            // db = helper.openMemoryDB();
            db = helper.openDB("testA.db");
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

    it('MATCH 2 on non-FTS-indexed columns', (done)=>
    {
        Sync(()=>
        {
            // let rows = db.all.sync(db, `select * from Person where AddressLine1 like '%camp%'`);
            let rows = db.all.sync(db, `select * from Person where city match 'south*' and email match 'kristi*'`);
            console.log(rows.length);
            done();
        });
    });

    it('MATCH 2 intersect on non-FTS-indexed columns', (done)=>
    {
        Sync(()=>
        {
            // let rows = db.all.sync(db, `select * from Person where AddressLine1 like '%camp%'`);
            let rows = db.all.sync(db, `select * from Person where city match 'south*' intersect 
            select * from Person where email match 'kristi*'`);
            console.log(rows.length);
            done();
        });
    });

    it('REGEXP 2', (done)=>
    {
        Sync(()=>
        {
            // let rows = db.all.sync(db, `select * from Person where lower(city) regexp '.*south\\S*.*' and
            // lower(email) regexp '.*\\S*hotmail\\S*.*'`);
            let rows = db.all.sync(db, `select * from Person where lower(city) regexp '.*south\\S*.*' and lower(email) regexp '.*kristi\\S*.*'`);
            // let rows = db.all.sync(db, `select * from Person where city regexp '.*south\\S*.*' and email regexp '.*\\S*hotmail\\S*.*'`);
            console.log(rows.length, rows);
            done();
        });
    });

    it('REGEXP 3', (done)=>
    {
        Sync(()=>
        {
            // let rows = db.all.sync(db, `select * from Person where lower(city) regexp '.*south\\S*.*' and
            // lower(email) regexp '.*\\S*hotmail\\S*.*'`);
            let rows = db.all.sync(db, `select * from Person where lower(city) regexp '.*south\\S*.*' 
            and lower(email) regexp '.*kristi\\S*.*'
            and lower(country) regexp '.*ka\\S*.*'`);
            // let rows = db.all.sync(db, `select * from Person where city regexp '.*south\\S*.*' and email regexp '.*\\S*hotmail\\S*.*'`);
            console.log(rows.length, rows);
            done();
        });
    });

    it('MATCH 1 on non-FTS-indexed columns', (done)=>
    {
        Sync(()=>
        {
            // let rows = db.all.sync(db, `select * from Person where AddressLine1 like '%camp%'`);
            let rows = db.all.sync(db, `select * from Person where email match 'kristi*'`);
            console.log(rows.length);
            done();
        });
    });

    it('REGEXP 1', (done)=>
    {
        Sync(()=>
        {
            // let rows = db.all.sync(db, `select * from Person where lower(city) regexp '.*south\\S*.*' and
            // lower(email) regexp '.*\\S*hotmail\\S*.*'`);
            let rows = db.all.sync(db, `select * from Person where lower(email) regexp '.*kristi\\S*.*'`);
            // let rows = db.all.sync(db, `select * from Person where city regexp '.*south\\S*.*' and email regexp '.*\\S*hotmail\\S*.*'`);
            console.log(rows.length, "\n");
            done();
        });
    });

    it('linear scan', (done)=>
    {
        Sync(()=>
        {
            // let rows = db.all.sync(db, `select * from Person where AddressLine1 like '%camp%'`);
            let rows = db.all.sync(db, `select * from Person where city = 'South Kayden' `);
            console.log('linear scan: ', rows.length);
            done();
        });
    });

    it('basic flow', (done)=>
    {
        Sync(()=>
        {
            let def = JSON.stringify(personMeta);
            db.exec.sync(db, `create virtual table if not exists Person using 'flexi_eav' ('${def}');`);

            db.exec.sync(db, `begin transaction`);
            try
            {
                for (var ii = 0; ii < 10000; ii++)
                {
                    let person = randomPersonArguments();
                    db.run.sync(db, `insert into Person (FirstName,
                LastName,
                Gender,
                AddressLine1,
                City,
                StateOrProvince,
                Country,
                ZipOrPostalCode,
                Email,
                Phone) values (
                $FirstName,
                $LastName,
                $Gender,
                $AddressLine1,
                $City,
                $StateOrProvince,
                $Country,
                $ZipOrPostalCode,
                $Email,
                $Phone);`, person);
                }

                db.exec.sync(db, `commit`);
            }
            catch (err)
            {
                db.exec.sync(db, `rollback`);
                throw err;
            }

            done();
        });
    });
});