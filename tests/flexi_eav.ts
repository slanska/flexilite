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

    it('basic flow', (done)=>
    {
        Sync(()=>
        {
            let def = JSON.stringify(personMeta);
            db.exec.sync(db, `create virtual table if not exists Person using 'flexi_eav' ('${def}');`);

            db.exec.sync(db, `begin transaction`);
            try
            {
                for (var ii = 0; ii < 1000; ii++)
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
            catch(err)
            {
                db.exec.sync(db, `rollback`);
                throw err;
            }

            var rows = db.all.sync(db, `select Country, rowid, LastName from Person where Country = 'Nepal';`);
            // var rows = db.all.sync(db, `select * from Person where (LastName = 'Doe' and FirstName in ('John', 'Mary',
            //  'Peter')) or Phone like '%555%';`);
            // var rows = db.all.sync(db, `select * from Person where  FirstName >= 'John' and LastName = 'Smi';`);
            // var rows = db.all.sync(db, `select * from Person where (LastName = 'Doe' and FirstName in ('John', 'Mary',
            //  'Peter')) ;`);
            console.log(rows);
            done();
        });
    });
});