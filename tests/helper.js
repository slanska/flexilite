/**
 * Created by Ruslan Skorynin on 04.10.2015.
 */
'use strict';
var chai = require('chai');
var expect = chai.expect;
var flexilite = require('../lib/FlexiliteAdapter');
var orm = require("orm");
var sqlite3 = require("sqlite3");
var util = require("util");
var path = require("path");
var shortid = require("shortid");
var faker = require("faker");
function ConnectAndSave() {
    var orm2 = orm;
    orm2.addAdapter('flexilite', flexilite);
    //var connString = util.format("sqlite://%s", path.join(__dirname, "data", "test.db"));
    var connString = util.format("flexilite://%s", path.join(__dirname, "data", "test.db"));
    orm.connect(connString, function (err, db) {
        if (err)
            throw err;
        console.log('DB opened\n');
        var Person = db.define("person", {
            name: String,
            surname: String,
            age: { type: "integer", unique: false, ui: { view: "text", width: "150" }, ext: { mappedTo: "C" } },
            male: { type: "boolean" },
            continent: ["Europe", "America", "Asia", "Africa", "Australia", "Antartica"],
            photo: Buffer,
            data: Object // JSON encoded
        }, {
            methods: {
                fullName: function () {
                    return this.name + ' ' + this.surname;
                }
            }
        });
        // add the table to the database
        db.sync(function (err) {
            if (err)
                throw err;
            // add a row to the person table
            Person.create({
                name: faker.name.firstName(1),
                surname: faker.name.lastName(1),
                age: faker.random.number({ min: 15, max: 60 }),
                extra_field: faker.random.number(),
                age2: faker.random.number({ min: 15, max: 60 }),
                data: { City: faker.address.city(), Street: faker.address.streetName() }
            }, function (err) {
                if (err)
                    throw err;
                // query the person table by surname
                Person.find({ surname: "Doe" }, function (err, people) {
                    // SQL: "SELECT * FROM person WHERE surname = 'Doe'"
                    if (err)
                        throw err;
                    console.log("People found: %d", people.length);
                    console.log("First person: %s, age %d", people[0].fullName(), people[0].age);
                    people[0].age = 16;
                    people[0].save(function (err) {
                        if (err)
                            throw err;
                        // err.msg = "under-age";
                        db.close(function () {
                        });
                    });
                });
            });
        });
    });
}
exports.ConnectAndSave = ConnectAndSave;
ConnectAndSave();
