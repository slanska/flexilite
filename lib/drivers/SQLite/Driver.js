/**
 * Created by slanska on 03.10.2015.
 */
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports", "lodash", "sqlite3", 'path', "./SQLiteDataRefactor"], factory);
    }
})(function (require, exports) {
    /// <reference path="../../../typings/tsd.d.ts"/>
    /// <reference path="./DBInterfaces.d.ts"/>
    'use strict';
    var _ = require("lodash");
    var sqlite3 = require("sqlite3");
    var Query = require("sql-query").Query;
    var Sync = require("syncho");
    var path = require('path');
    var SQLiteDataRefactor_1 = require("./SQLiteDataRefactor");
    var Flexilite;
    (function (Flexilite) {
        var SQLite;
        (function (SQLite) {
            /*
             Implements Flexilite driver for node-orm.
             Uses SQLite as a backend storage
             */
            var Driver = (function () {
                function Driver(config, connection, opts) {
                    var _this = this;
                    this.dialect = 'sqlite';
                    this.config = config || {};
                    this.opts = opts || {};
                    if (!this.config.timezone) {
                        this.config.timezone = "local";
                    }
                    this.query = new Query({ dialect: this.dialect, timezone: this.config.timezone });
                    this.customTypes = {}; // TODO Any custom types?
                    if (connection) {
                        this.db = connection;
                    }
                    else {
                        // on Windows, paths have a drive letter which is parsed by
                        // url.parse() as the hostname. If host is defined, assume
                        // it's the drive letter and add ":"
                        var win32 = process.platform == "win32" && config.host && config.host.match(/^[a-z]$/i);
                        console.log(config);
                        var fn = ((config.host ? (win32 ? config.host + ":" : config.host) : "") + (config.pathname || "")) || ':memory:';
                        this.db = sqlite3.cached.Database(fn, SQLITE_OPEN_FLAGS.SHARED_CACHE | sqlite3.OPEN_READWRITE | SQLITE_OPEN_FLAGS.WAL);
                        // FIXME dynamically determine library path based on OS and platform
                        var extLibPath_1 = path.join(__dirname, "../../sqlite-extensions/bin/libsqlite_extensions.dylib");
                        Sync.Fiber(function () {
                            // TODO Handle loading library
                            _this.db.loadExtension.sync(_this.db, extLibPath_1);
                        }).run();
                    }
                    this.aggregate_functions = ["ABS", "ROUND",
                        "AVG", "MIN", "MAX",
                        "RANDOM",
                        "SUM", "COUNT",
                        "DISTINCT"];
                }
                // TODO Remove as it is not needed
                Driver.prototype.getViewName = function (table) {
                    return table;
                };
                Driver.prototype.convertTimezone = function (tz) {
                    if (tz == "Z")
                        return 0;
                    var m = tz.match(/([\+\-\s])(\d\d):?(\d\d)?/);
                    if (m) {
                        return (m[1] == '-' ? -1 : 1) * (parseInt(m[2], 10) + ((m[3] ? parseInt(m[3], 10) : 0) / 60)) * 60;
                    }
                    return false;
                };
                // TODO DDL defines standard SQLite sync and drop. Flexilite has custom
                // logic for these operations, so DDL should be exluded
                // TODO _.extend(Driver.prototype, shared, DDL);
                //_.extend(Driver.prototype, shared);
                Driver.prototype.ping = function (cb) {
                    process.nextTick(cb);
                    return this;
                };
                Driver.prototype.on = function (ev, cb) {
                    if (ev == "error") {
                        this.db.on("error", cb);
                    }
                    return this;
                };
                Driver.prototype.connect = function (cb) {
                    process.nextTick(cb);
                };
                Driver.prototype.close = function (cb) {
                    this.db.close();
                    if (_.isFunction(cb))
                        process.nextTick(cb);
                };
                ;
                Driver.prototype.getQuery = function () {
                    return this.query;
                };
                Driver.prototype.execSimpleQuery = function (query, cb) {
                    if (this.opts.debug) {
                        require("./Debug").sql('sqlite', query);
                    }
                    // TODO Process query
                    this.db.all(query, cb);
                };
                Driver.prototype.find = function (fields, table, conditions, opts, cb) {
                    // TODO Generate query based on arguments
                    var q = this.query.select()
                        .from(this.getViewName(table)).select(fields);
                    if (opts.offset) {
                        q.offset(opts.offset);
                    }
                    if (typeof opts.limit == "number") {
                        q.limit(opts.limit);
                    }
                    else if (opts.offset) {
                        // OFFSET cannot be used without LIMIT so we use the biggest INTEGER number possible
                        q.limit('9223372036854775807');
                    }
                    if (opts.order) {
                        for (var i = 0; i < opts.order.length; i++) {
                            q.order(opts.order[i][0], opts.order[i][1]);
                        }
                    }
                    if (opts.merge) {
                        q.from(opts.merge.from.table, opts.merge.from.field, opts.merge.to.field).select(opts.merge.select);
                        if (opts.merge.where && Object.keys(opts.merge.where[1]).length) {
                            q = q.where(opts.merge.where[0], opts.merge.where[1], opts.merge.table || null, conditions);
                        }
                        else {
                            q = q.where(opts.merge.table || null, conditions);
                        }
                    }
                    else {
                        q = q.where(conditions);
                    }
                    if (opts.exists) {
                        for (var k in opts.exists) {
                            q.whereExists(opts.exists[k].table, table, opts.exists[k].link, opts.exists[k].conditions);
                        }
                    }
                    q = q.build();
                    if (this.opts.debug) {
                        require("./Debug").sql('sqlite', q);
                    }
                    // TODO
                    this.db.all(q, cb);
                };
                /*
                 Returns count of found records
                 */
                Driver.prototype.count = function (table, conditions, opts, cb) {
                    var q = this.query.select()
                        .from(this.getViewName(table))
                        .count(null, 'c');
                    if (opts.merge) {
                        q.from(opts.merge.from.table, opts.merge.from.field, opts.merge.to.field);
                        if (opts.merge.where && Object.keys(opts.merge.where[1]).length) {
                            q = q.where(opts.merge.where[0], opts.merge.where[1], conditions);
                        }
                        else {
                            q = q.where(conditions);
                        }
                    }
                    else {
                        q = q.where(conditions);
                    }
                    if (opts.exists) {
                        for (var k in opts.exists) {
                            var opt = opts.exists[k];
                            q.whereExists(opt.table, table, opt.link, opt.conditions);
                        }
                    }
                    q = q.build();
                    if (this.opts.debug) {
                        require("./Debug").sql('sqlite', q);
                    }
                    this.db.all(q, cb);
                };
                /*
                 Inserts or updates single object to the database.
                 Returns newly generated objectID (for inserted object)
                 */
                // private saveObject(table:string, data:any, objectID:number, hostID:number):number
                // {
                //     var self = this;
                //
                //     var collDef = self.getClassDefByName(table, false, true);
                //     var q = '';
                //
                //     // TODO
                //     // if (!objectID)
                //     //     objectID = self.generateObjectID();
                //     if (!hostID)
                //         hostID = objectID;
                //
                //     var schemaDef:IDataToSave = null; // TODO
                //     // // self.extractSchemaProperties(collDef, data);
                //
                //     q = self.query.insert()
                //             .into(this.getViewName(table))
                //             .set(schemaDef.SchemaData)
                //             .build() + ';';
                //
                //     var schemaProps = {};
                //     var nonSchemaProps:IFlexiRefValue[] = [];
                //
                //     for (var propName in data)
                //     {
                //         // Shortcut to property data
                //         var v = data[propName];
                //
                //         // var propInfo:IFlexiRefValue = {
                //         //     ObjectID: objectID, classDef: classDef,
                //         //     propName: propName, propIndex: 0, value: v
                //         // };
                //         // TODO self.processPropertyForSave(propInfo, schemaProps, nonSchemaProps);
                //     }
                //
                //     var info = self.db.all.sync(self.db, q);
                //
                //     nonSchemaProps.forEach(function (item:IFlexiRefValue, idx, arr)
                //     {
                //         self.execSQL(`insert or replace into [.values_view] (ObjectID, PropertyID, PropIndex,
                //         [Value], [ctlv]) values (?, ?, ?, ?, ?, ?, ?)`,
                //             item.ObjectID, item.PropertyID, item.PropIndex, item.Value, item.ctlv);
                //         //TODO Set ctlo. use propInfo?
                //     });
                //
                //     if (self.opts.debug)
                //     {
                //         require("./Debug").sql('sqlite', q);
                //     }
                //
                //     // FIXME - needed? self.db.all.sync(self.db, q);
                //
                //     return objectID;
                // }
                /*
        
                 */
                Driver.prototype.execSQL = function (sql) {
                    var args = [];
                    for (var _i = 1; _i < arguments.length; _i++) {
                        args[_i - 1] = arguments[_i];
                    }
                    var result;
                    if (args && args.length > 0)
                        result = this.db.run.sync(this.db, sql, args);
                    else
                        result = this.db.exec.sync(this.db, sql);
                    return result;
                };
                /*
        
                 */
                // insert(table:string, data:any, keyProperties, cb)
                // {
                //     if (!keyProperties)
                //         return cb(null);
                //
                //     var self = this;
                //     Sync(function ()
                //         {
                //             self.execSQL('savepoint a1;');
                //             try
                //             {
                //                 var objectID = self.saveObject(table, data, null, null);
                //                 var i, ids = {}, prop;
                //
                //                 if (keyProperties.length == 1 && keyProperties[0].type == 'serial')
                //                 {
                //                     ids[keyProperties[0].name] = objectID;
                //                 }
                //                 else
                //                 {
                //                     for (i = 0; i < keyProperties.length; i++)
                //                     {
                //                         prop = keyProperties[i];
                //                         ids[prop.name] = data[prop.mapsTo] || null;
                //                     }
                //                 }
                //                 self.execSQL('release a1;');
                //
                //                 return cb(null, ids);
                //             }
                //             catch (err)
                //             {
                //                 self.execSQL('rollback;');
                //                 throw err;
                //             }
                //         }
                //     );
                // }
                /*
                 Updates existing data object.
                 */
                Driver.prototype.update = function (table, changes, conditions, cb) {
                    var self = this;
                    Sync(function () {
                        // TODO Iterate via data's properties
                        // Props defined in schema, are updated via updatable view
                        // Non-schema props are updated/inserted as one batch to Values table
                        // TODO Alter where clause to add classID
                        var q = self.query.update()
                            .into(this.getViewName(table))
                            .set(changes)
                            .where(conditions)
                            .build();
                        if (this.opts.debug) {
                            require("./Debug").sql('sqlite', q);
                        }
                        self.db.all(q, cb);
                    });
                };
                /*
        
                 */
                Driver.prototype.remove = function (table, conditions, cb) {
                    // TODO Alter where clause to add classID
                    var q = this.query.remove()
                        .from(table)
                        .where(conditions)
                        .build();
                    if (this.opts.debug) {
                        require("./Debug").sql('sqlite', q);
                    }
                    this.db.all(q, cb);
                };
                Driver.prototype.execQuery = function (qry, qryParams, callback) {
                    if (arguments.length == 2) {
                        var query = arguments[0];
                        var cb = arguments[1];
                    }
                    else if (arguments.length == 3) {
                        var query = this.query.escape(arguments[0], arguments[1]);
                        var cb = arguments[2];
                    }
                    return this.execSimpleQuery(query, cb);
                };
                /*
        
                 */
                Driver.prototype.eagerQuery = function (association, opts, keys, cb) {
                    var desiredKey = Object.keys(association.field);
                    var assocKey = Object.keys(association.mergeAssocId);
                    var where = {};
                    where[desiredKey] = keys;
                    var query = this.query.select()
                        .from(association.model.table)
                        .select(opts.only)
                        .from(association.mergeTable, assocKey, opts.keys)
                        .select(desiredKey).as("$p")
                        .where(association.mergeTable, where)
                        .build();
                    this.execSimpleQuery(query, cb);
                };
                /*
        
                 */
                Driver.prototype.clear = function (table, cb) {
                    var debug = this.opts.debug;
                    this.execQuery("DELETE FROM ??", [this.getViewName(table)], function (err) {
                        if (err)
                            return cb(err);
                        this.execQuery("DELETE FROM ?? WHERE NAME = ?", ['sqlite_sequence', this.getViewName(table)], cb);
                    }.bind(this));
                };
                /*
        
                 */
                Driver.prototype.valueToProperty = function (value, property) {
                    var v, customType;
                    switch (property.type) {
                        case "boolean":
                            value = !!value;
                            break;
                        case "object":
                            if (typeof value == "object" && !Buffer.isBuffer(value)) {
                                break;
                            }
                            try {
                                value = JSON.parse(value);
                            }
                            catch (e) {
                                value = null;
                            }
                            break;
                        case "number":
                            if (typeof value != 'number' && value !== null) {
                                v = Number(value);
                                if (!isNaN(v)) {
                                    value = v;
                                }
                            }
                            break;
                        case "date":
                            if (typeof value == 'string') {
                                if (value.indexOf('Z', value.length - 1) === -1) {
                                    value = new Date(value + 'Z');
                                }
                                else {
                                    value = new Date(value);
                                }
                                if (this.config.timezone && this.config.timezone != 'local') {
                                    var tz = this.convertTimezone(this.config.timezone);
                                    // shift local to UTC
                                    value.setTime(value.getTime() - (value.getTimezoneOffset() * 60000));
                                    if (tz !== false) {
                                        // shift UTC to timezone
                                        value.setTime(value.getTime() - (tz * 60000));
                                    }
                                }
                            }
                            break;
                        default:
                            customType = this.customTypes[property.type];
                            if (customType && 'valueToProperty' in customType) {
                                value = customType.valueToProperty(value);
                            }
                    }
                    return value;
                };
                /*
                 Converts model property to value
                 */
                Driver.prototype.propertyToValue = function (value, property) {
                    var customType;
                    switch (property.type) {
                        case "boolean":
                            value = (value) ? 1 : 0;
                            break;
                        case "object":
                            if (value !== null) {
                                if (Buffer.isBuffer(value))
                                    value = value.toString('base64');
                            }
                            break;
                        case "date":
                            if (this.config.query && this.config.query.strdates) {
                                if (value instanceof Date) {
                                    var year = value.getUTCFullYear();
                                    var month = value.getUTCMonth() + 1;
                                    if (month < 10) {
                                        month = '0' + month;
                                    }
                                    var date = value.getUTCDate();
                                    if (date < 10) {
                                        date = '0' + date;
                                    }
                                    var strdate = year + '-' + month + '-' + date;
                                    if (property.time === false) {
                                        value = strdate;
                                        break;
                                    }
                                    var hours = value.getUTCHours();
                                    if (hours < 10) {
                                        hours = '0' + hours;
                                    }
                                    var minutes = value.getUTCMinutes();
                                    if (minutes < 10) {
                                        minutes = '0' + minutes;
                                    }
                                    var seconds = value.getUTCSeconds();
                                    if (seconds < 10) {
                                        seconds = '0' + seconds;
                                    }
                                    var millis = value.getUTCMilliseconds();
                                    if (millis < 10) {
                                        millis = '0' + millis;
                                    }
                                    if (millis < 100) {
                                        millis = '0' + millis;
                                    }
                                    strdate += ' ' + hours + ':' + minutes + ':' + seconds + '.' + millis + '000';
                                    value = strdate;
                                }
                            }
                            break;
                        default:
                            customType = this.customTypes[property.type];
                            if (customType && 'propertyToValue' in customType) {
                                value = customType.propertyToValue(value);
                            }
                    }
                    return value;
                };
                Object.defineProperty(Driver.prototype, "isSql", {
                    /*
                     Overrides isSql property for driver
                     */
                    get: function () {
                        return true;
                    },
                    enumerable: true,
                    configurable: true
                });
                /*
                 Loads class definition with properties by class name
                 If class does not exist yet and createIfNotExist === true, new instance of IClass
                 will be created and registered in database.
                 If class does not exist and no new class should be registered, class def will
                 be created in memory. In this case ClassID will be set to null, Properties - to empty object
                 */
                Driver.prototype.getClassDefByName = function (className, createIfNotExist, loadProperties) {
                    var self = this;
                    var selStmt = self.db.prepare("select * from [.collections] where [NameID] = (select [NameID] from [.names] where [Value] = ?)");
                    var rows = selStmt.all.sync(selStmt, className);
                    var collDef;
                    if (rows.length === 0) 
                    // Collection not found
                    {
                        if (createIfNotExist) {
                            var insCStmt = self.db.prepare("insert or ignore into [.names] ([Value]) values (@name);\n                        insert or replace into [.collections] ([NameID], ViewOutdated) values (select [NameID] from [.names] where [Value] = @name), 1);\n                    select * from [.classes] where [ClassName] = @name;");
                            insCStmt.run.sync(insCStmt, { name: className });
                            // Reload class def with all updated properties
                            collDef = selStmt.all.sync(selStmt, className)[0];
                        }
                        else 
                        //
                        {
                            collDef = {};
                            // TODO collDef.NameID = className;
                            collDef.ClassID = null;
                        }
                    }
                    else {
                        collDef = rows[0];
                        // TODO collDef.Properties = {};
                        if (loadProperties) 
                        // Class found. Try to load properties
                        {
                            var props = self.db.all.sync(self.db, 'select * from [.class_properties] where [ClassID] = ?', collDef.ClassID) || {};
                            props.forEach(function (p, idx, propArray) {
                                // TODO collDef.Properties[p.PropertyName] = p;
                            });
                        }
                    }
                    return collDef;
                };
                /*
        
                 */
                Driver.prototype.registerName = function (attrName, pluralName) {
                    var self = this;
                    var result = self.execSQL("insert or replace [.attributes] (name, pluralName) values (?, ?); \n            select id from [.attributes] where name = ?;", attrName, pluralName, attrName);
                    return result;
                };
                /*
                 Registers a new class definition based on the sample data
                 */
                Driver.prototype.registerCollectionByObject = function (className, data, saveData) {
                    if (saveData === void 0) { saveData = false; }
                    var self = this;
                    this.execSQL('savepoint a1;');
                    try {
                        // Register properties and class name as attributes. Obtain their IDs
                        var classID = this.registerName(className);
                        // Process all properties
                        var classProps = { properties: {} };
                        var schemaProps = { properties: {} };
                        _.forEach(data, function (prop, name) {
                            var propID = self.registerName(name);
                            classProps.properties[propID] = {};
                            schemaProps.properties[propID] = { JSONPath: "$." + name };
                        });
                        // Create class object
                        var createClassSQL = "insert or ignore into [.classes] (ClassID, ClassName, SchemaOutdated, Properties) \n                values (" + classID + ", ?, 1, ?);";
                        self.execSQL(createClassSQL, className, JSON.stringify(classProps));
                        // Create schema object
                        var createSchemaSQL = "insert into [.schemas] (ClassID) \n                values (" + classID + "); select last_row_id();";
                        var schemaID = self.execSQL(createSchemaSQL, JSON.stringify(schemaProps));
                        self.execSQL("update [.classes] set CurrentSchemaID = ?", schemaID);
                        // Optionally, save data
                        if (saveData) {
                            var insertObjSQL = "insert into [.objects] (ClassID, SchemaID, Data) values (?, ?, ?);";
                            self.execSQL(insertObjSQL, classID, schemaID, JSON.stringify(data));
                        }
                        this.execSQL('release a1;');
                    }
                    catch (err) {
                        this.execSQL('rollback;');
                        throw err;
                    }
                    return null;
                };
                /*
                 Does reverse engineering on the given database.
                 Analyses existing tables, constraints, indexes, foreign keys.
                 Returns dictionary with class definitions (IClass)
                 TODO: Declare this method in the IFlexiliteDriver interface
                 */
                Driver.prototype.reverseEngineer = function (dbConnection) {
                };
                /*
                 sync model
                 create .class
                 for each all_properties
                 create .class
                 create .class_property: ctlv = REFERENCE_OWN, check indexes
                 for each extend_assosiations
                 create .class
                 create .class_property: ctlv = REFERENCE
        
        
                 saveObject
                 for each property
                 if is object
                 if schema && referencedClassID - use it
                 else create .class by property name
        
                 save object
                 */
                Driver.prototype.sync = function (opts, callback) {
                    var self = this;
                    // Wrap all calls into Fibers syncho
                    Sync(function () {
                        try {
                            var refactor = new SQLiteDataRefactor_1.SQLiteDataRefactor(self.db);
                            refactor.generateClassAndSchemaDefForSync(opts);
                            callback();
                        }
                        catch (err) {
                            callback(err);
                        }
                    });
                };
                // TODO Implement drop
                Driver.prototype.drop = function (opts, callback) {
                    //table - The name of the table
                    //properties
                    //one_associations
                    //many_associations
                    var qry = "select * from [.classes] where [ClassName] = " + opts.table + ";    ";
                    this.db.exec(qry);
                    // TODO Delete objects?
                    callback();
                };
                Driver.prototype.hasMany = function (Model, association) {
                    // TODO Process relations
                    return {
                        has: function (Instance, Associations, conditions, cb) {
                            cb();
                        },
                        get: function (Instance, conditions, options, createInstance, cb) {
                            cb();
                        },
                        add: function (Instance, Association, data, cb) {
                            cb();
                        },
                        del: function (Instance, Associations, cb) {
                            cb();
                        }
                    };
                };
                return Driver;
            }());
            SQLite.Driver = Driver;
        })(SQLite = Flexilite.SQLite || (Flexilite.SQLite = {}));
    })(Flexilite || (Flexilite = {}));
    return Flexilite.SQLite.Driver;
});
//# sourceMappingURL=Driver.js.map