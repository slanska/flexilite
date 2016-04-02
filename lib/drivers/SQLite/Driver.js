/**
 * Created by slanska on 03.10.2015.
 */
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports", "lodash", "sqlite3", 'path', 'object-hash'], factory);
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
    var objectHash = require('object-hash');
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
                        this.db = sqlite3.cached.Database(fn, 131072 /* SHARED_CACHE */ | sqlite3.OPEN_READWRITE | 524288 /* WAL */);
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
                 Iterates through all keys of given data and determines which keys are scalar and defined in class schema.
                 Returns object with properties separates into these 2 groups: schema and extra.ß
                 */
                Driver.prototype.extractSchemaProperties = function (schemaDef, data) {
                    var result = { SchemaData: {}, ExtData: {} };
                    for (var pi in data) {
                        var schemaProp = false;
                        // Include only properties that are defined in class schema and NOT defined as reference properties
                        if (schemaDef.properties.hasOwnProperty(pi) && !schemaDef.properties[pi].ReferencedClassID) {
                            var v = data[pi];
                            if (!_.isObject(v) && !_.isArray(v)) {
                                result.SchemaData[pi] = v;
                                schemaProp = true;
                            }
                        }
                        if (!schemaProp)
                            result.ExtData[pi] = data[pi];
                    }
                    return result;
                };
                /*
                 Processes individual property. Depending on actual property's value and
                 whether it is included in schema, property will be either added to the list of EAV rows
                 or to the list to inserted/updated via view
                 @param propInfo - data for individual property to be processed
                 @param schemaProps - object with all properties which are defined in schema
                 @param nonSchemaProps - array of prop definitions which are not defined in class schema
                 */
                // private processPropertyForSave(propInfo:IPropertyToSave, schemaProps:any, eavItems:IEAVItem[])
                // {
                //     var self = this;
                //
                //     // Check if property is included into schema
                //     var schemaProp = propInfo.classDef.Properties[propInfo.propName];
                //
                //     // Make sure that property is registered as class
                //     var propClass = schemaProp ? self.getClassDefByID(schemaProp.PropertyID) : self.getClassDefByName(propInfo.propName, true, false);
                //     var pid = propClass.CollectionID.toString();
                //
                //     function doProp(propIdPrefix:string)
                //     {
                //         if (propInfo.propIndex === 0 && schemaProp)
                //         {
                //             schemaProps[propInfo.propName] = propInfo.value;
                //         }
                //         else
                //         {
                //             pid = propIdPrefix + pid;
                //             eavItems.push({
                //                 objectID: propInfo.objectID,
                //                 hostID: propInfo.hostID,
                //                 propID: propClass.CollectionID, propIndex: propInfo.propIndex,
                //                 value: propInfo.value,
                //                 classID: propClass.CollectionID,
                //                 ctlv: schemaProp ? schemaProp.ctlv : VALUE_CONTROL_FLAGS.NONE
                //             });
                //         }
                //     }
                //
                //     // Determine actual property type
                //     if (Buffer.isBuffer(propInfo.value))
                //     // Binary (BLOB) value. Store as base64 string
                //     {
                //         propInfo.value = propInfo.value.toString('base64');
                //         doProp('X');
                //     }
                //     else
                //         if (_.isDate(propInfo.value))
                //         // Date value. Store as Julian value (double value)
                //         {
                //             propInfo.value = (<Date>propInfo.value).getMilliseconds();
                //             doProp('D');
                //         }
                //         else
                //             if (_.isArray(propInfo.value))
                //             // List of properties
                //             {
                //                 propInfo.value.forEach(function (item, idx, arr)
                //                 {
                //                     var pi:IPropertyToSave = propInfo;
                //                     pi.propIndex = idx + 1;
                //                     self.processPropertyForSave(pi, schemaProps, eavItems);
                //                 });
                //             }
                //             else
                //                 if (_.isObject(propInfo.value))
                //                 // Reference to another object
                //                 {
                //                     var refClassName:string;
                //                     if (schemaProp)
                //                     {
                //                         var refClassID = schemaProp.ReferencedClassID;
                //                         var refClass = self.getClassDefByID(refClassID);
                //                         refClassName = refClass.NameID;
                //                     }
                //                     else
                //                     {
                //                         refClassName = propInfo.propName;
                //                     }
                //
                //                     // TODO Check if object already exists???
                //                     var refObjectID = self.saveObject(refClassName, propInfo.value, null, propInfo.hostID);
                //                     eavItems.push({
                //                         objectID: propInfo.objectID,
                //                         hostID: propInfo.hostID,
                //                         classID: propInfo.classDef.CollectionID,
                //                         propID: propClass.CollectionID,
                //                         propIndex: 0,
                //                         ctlv: schemaProp ? schemaProp.ctlv : VALUE_CONTROL_FLAGS.REFERENCE_OWN,
                //                         value: refObjectID
                //                     });
                //                 }
                //                 else
                //                 {
                //                     // Regular scalar property
                //                     doProp('');
                //                 }
                // }
                /*
                 Inserts or updates single object to the database.
                 Returns newly generated objectID (for inserted object)
                 */
                Driver.prototype.saveObject = function (table, data, objectID, hostID) {
                    var self = this;
                    var collDef = self.getClassDefByName(table, false, true);
                    var q = '';
                    // TODO
                    // if (!objectID)
                    //     objectID = self.generateObjectID();
                    if (!hostID)
                        hostID = objectID;
                    var schemaDef = null; // TODO
                    // // self.extractSchemaProperties(collDef, data);
                    q = self.query.insert()
                        .into(this.getViewName(table))
                        .set(schemaDef.SchemaData)
                        .build() + ';';
                    var schemaProps = {};
                    var nonSchemaProps = [];
                    for (var propName in data) {
                        // Shortcut to property data
                        var v = data[propName];
                    }
                    var info = self.db.all.sync(self.db, q);
                    nonSchemaProps.forEach(function (item, idx, arr) {
                        self.execSQL("insert or replace into [.values_view] (ObjectID, ClassID, PropertyID, PropIndex,\n                [Value], [ctlv]) values (?, ?, ?, ?, ?, ?, ?)", item.ObjectID, item.ClassID, item.PropertyID, item.PropIndex, item.Value, item.ctlv);
                        //TODO Set ctlo. use propInfo?
                    });
                    if (self.opts.debug) {
                        require("./Debug").sql('sqlite', q);
                    }
                    // FIXME - needed? self.db.all.sync(self.db, q);
                    return objectID;
                };
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
                Driver.prototype.insert = function (table, data, keyProperties, cb) {
                    if (!keyProperties)
                        return cb(null);
                    var self = this;
                    Sync(function () {
                        self.execSQL('savepoint a1;');
                        try {
                            var objectID = self.saveObject(table, data, null, null);
                            var i, ids = {}, prop;
                            if (keyProperties.length == 1 && keyProperties[0].type == 'serial') {
                                ids[keyProperties[0].name] = objectID;
                            }
                            else {
                                for (i = 0; i < keyProperties.length; i++) {
                                    prop = keyProperties[i];
                                    ids[prop.name] = data[prop.mapsTo] || null;
                                }
                            }
                            self.execSQL('release a1;');
                            return cb(null, ids);
                        }
                        catch (err) {
                            self.execSQL('rollback;');
                            throw err;
                        }
                    });
                };
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
                /*
        
                 */
                Driver.prototype.getNameByID = function (name) {
                    var rows = this.db.run.sync(this.db, "insert or ignore into [.names] ([Value]) values (@name);\n            select NameID from [.names] where [Value] = @name limit 1", { name: name });
                    var result = rows[0].NameID;
                    return result;
                };
                /*
                 Synchronizes node-orm model to .classes and .class_properties.
                 Makes updates to the database.
                 Returns instance of ICollectionDef, with all changes applied
                 NOTE: this function is intended to run inside Syncho wrapper
                 */
                /*
                 Links in wiki:
                 hasMany https://github.com/dresende/node-orm2/wiki/hasMany
        
                 hasOne: https://github.com/dresende/node-orm2/wiki/hasOne
                 extendsTo: https://github.com/dresende/node-orm2/wiki/extendsTo
        
                 hasMany and hasOne are converted into reference properties
                 */
                Driver.prototype.generateClassAndSchemaDefForSync = function (model) {
                    var self = this;
                    // TODO
                    // Normalize model
                    var converter = new SchemaHelper(self.db, model);
                    converter.getNameID = self.getNameByID.bind(self);
                    converter.convert();
                    var schemaData = {};
                    schemaData.Data = converter.targetSchema;
                    converter.targetClass;
                    // Check if this schema is already defined.
                    // By schema signature
                    var hashValue = objectHash(schemaData);
                    var schemas = self.db.all.sync(self.db, "select * from [.schemas] where Hash = ?", hashValue);
                    var existingSchema = _.find(schemas, function (item) {
                        if (_.isEqual(item.Data, schemaData.Data))
                            return true;
                    });
                    if (!existingSchema) {
                        // create new one
                        var sql = "insert into [.schemas] into (NameID, Data, Hash) values (@NameID, @Data, @Hash);";
                        self.db.run.sync(self.db, sql, {
                            NameID: self.getNameByID(model.table),
                            Data: JSON.stringify(schemaData.Data),
                            Hash: hashValue
                        });
                    }
                    // Load existing model, if it exists
                    var classDef = this.getClassDefByName(model.table, true, true);
                    // Assume all existing properties as candidates for removal
                    var deletedProperties = [];
                    _.forEach(classDef.Data.properties, function (prop, propID) {
                        deletedProperties.push(propID);
                    });
                    var insCStmt = self.db.prepare("insert or ignore into [.classes] ([ClassName], [DefaultScalarType], [ClassID])\n            select ?, ?, (select ClassID from [.classes] where ClassName = ? limit 1);");
                    var insCPStmt = null;
                    function saveClassProperty(cp) {
                        if (!insCPStmt || insCPStmt === null) {
                            insCPStmt = self.db.prepare("insert or replace into [.class_properties]\n                ([ClassID], [PropertyID],\n     [PropertyName], [TrackChanges], [DefaultValue], [DefaultDataType],\n     [MinOccurences], [MaxOccurences], [Unique], [MaxLength], [ReferencedClassID],\n     [ReversePropertyID], [ColumnAssigned]) values (?,\n     (select [ClassID] from [.classes] where [ClassName] = ? limit 1),\n      ?, ?, ?, ?,\n      ?, ?, ?, ?, ?, ?, ?);");
                        }
                        insCPStmt.run.sync(insCPStmt, [
                            classDef.ClassID,
                            propName,
                            cp.PropertyName,
                            cp.TrackChanges,
                            cp.DefaultValue,
                            cp.DefaultDataType,
                            cp.MinOccurences,
                            cp.MaxOccurences,
                            cp.Unique,
                            cp.MaxLength,
                            cp.ReferencedClassID,
                            cp.ReversePropertyID,
                            null
                        ]);
                    }
                    // Check properties
                    for (var propName in model.allProperties) {
                        var pd = model.allProperties[propName];
                        // Unmark property from removal candidates list
                        _.remove(deletedProperties, function (value) { return value == propName; });
                        var cp = schemaData.properties[propName.toLowerCase()];
                        if (!cp) {
                            schemaData.properties[propName.toLowerCase()] = cp = {};
                        }
                        // Depending on klass, treat properties differently
                        // Possible values: primary, hasOne, hasMany
                        switch (pd.klass) {
                            case 'primary':
                                cp.DefaultDataType = pd.type || cp.DefaultDataType;
                                cp.Indexed = pd.indexed || cp.Indexed;
                                cp.PropertyName = propName;
                                cp.Unique = pd.unique || cp.Unique;
                                cp.DefaultValue = pd.defaultValue || cp.DefaultValue;
                                var ext = pd.ext || {};
                                // TODO cp.ColumnAssigned = ext. || cp.ColumnAssigned;
                                cp.MaxLength = ext.rules.maxLength || cp.MaxLength;
                                cp.MaxOccurences = ext.rules.maxOccurences || cp.MaxOccurences;
                                cp.MinOccurences = ext.rules.minOccurences || cp.MinOccurences;
                                cp.ValidationRegex = ext.rules.regex || cp.ValidationRegex;
                                insCStmt.run.sync(insCStmt, [propName, cp.DefaultDataType, propName]);
                                if (pd.type === 'object') {
                                    var refModel;
                                    var refClass = this.registerCollectionByObject(propName, null, true);
                                    cp.ReferencedClassID = refClass.ClassID;
                                }
                                else {
                                }
                                break;
                            case 'hasOne':
                                var refOneProp = _.find(model.one_associations, function (item, idx, arr) {
                                    return (item.field.hasOwnProperty(propName));
                                });
                                if (refOneProp) {
                                    var refClass = this.getClassDefByName(refOneProp.model.table, true, true);
                                    cp.ReferencedClassID = refClass.ClassID;
                                    // FIXME create reverse property & set it as ReversePropertyID
                                    //cp.ReversePropertyID =
                                    cp.MinOccurences = refOneProp.required ? 1 : 0;
                                    cp.MaxOccurences = 1;
                                }
                                else {
                                    throw '';
                                }
                                break;
                            case 'hasMany':
                                var refManyProp = _.find(model.many_associations, function (item, idx, arr) {
                                    return (item.field.hasOwnProperty(propName));
                                });
                                if (refManyProp) {
                                }
                                else {
                                    throw '';
                                }
                                break;
                        }
                        saveClassProperty(cp);
                    }
                    for (var oneRel in model.one_associations) {
                        var assoc = model.one_associations[oneRel];
                        var cp = schemaData.properties[oneRel.toLowerCase()];
                        if (!cp) {
                            schemaData.properties[oneRel.toLowerCase()] = cp = {};
                            cp.PropertyName = oneRel;
                        }
                        cp.Indexed = true;
                        cp.MinOccurences = assoc.required ? 1 : 0;
                        cp.MaxOccurences = 1;
                        var refClass = self.getClassDefByName(assoc.model.table, true, true);
                        cp.ReferencedClassID = refClass.ClassID;
                        // Set reverse property
                        saveClassProperty(cp);
                    }
                    for (var manyRel in model.many_associations) {
                        var assoc = model.one_associations[manyRel];
                        var cp = schemaData.properties[manyRel.toLowerCase()];
                        if (!cp) {
                            schemaData.properties[manyRel.toLowerCase()] = cp = {};
                            cp.PropertyName = manyRel;
                        }
                        cp.Indexed = true;
                        cp.MinOccurences = assoc.required ? 1 : 0;
                        cp.MaxOccurences = 1 << 31;
                        var refClass = self.getClassDefByName(assoc.model.table, true, true);
                        cp.ReferencedClassID = refClass.ClassID;
                        // Set reverse property
                        saveClassProperty(cp);
                    }
                    classDef = this.getClassDefByName(model.table, false, true);
                    return { Class: classDef, Schema: schemaData };
                };
                /*
                 Generates beginning of INSTEAD OF trigger for dynamic view
                 */
                Driver.prototype.generateTriggerBegin = function (viewName, triggerKind, triggerSuffix, when) {
                    if (triggerSuffix === void 0) { triggerSuffix = ''; }
                    if (when === void 0) { when = ''; }
                    return "/* Autogenerated code. Do not edit or delete. " + (viewName[0].toUpperCase() + viewName.slice(1)) + "." + triggerKind + " trigger*/\n\n            drop trigger if exists [trig_" + viewName + "_" + triggerKind + triggerSuffix + "];\n    create trigger if not exists [trig_" + viewName + "_" + triggerKind + triggerSuffix + "] instead of " + triggerKind + " on [" + viewName + "]\n    for each row\n\n    " + when + "\n    begin\n";
                };
                /*
                 Generates constraints for INSTEAD OF triggers for dynamic view
                 */
                Driver.prototype.generateConstraintsForTrigger = function (collectionName, schemaDef) {
                    var result = '';
                    // Iterate through all properties
                    _.forEach(schemaDef.properties, function (p, propID) {
                        // TODO Get property name by ID
                        // Is required/not null?
                        if (p.rules.minOccurences > 0)
                            result += "when new.[" + propID + "] is null then '" + propID + " is required'\n";
                        // Is unique
                        // TODO Unique in Class.Property, unique in Property (all classes)
                        //         if (p.Unique)
                        //             result += `when exists(select 1 from [${collectionName}] v where v.[ObjectID] <> new.[ObjectID]
                        // and v.[${propName}] = new.[${propName}]) then '${propName} has to be unique'\n`;
                        // Range validation
                        // Max length validation
                        if ((p.rules.maxLength || 0) !== 0 && (p.rules.maxLength || 0) !== -1)
                            result += "when typeof(new.[" + propID + "]) in ('text', 'blob')\n        and len(new.[" + propID + "] > " + p.rules.maxLength + ") then 'Length of " + propID + " exceeds max value of " + p.rules.maxLength + "'\n";
                        // Regex validation
                        // TODO Use extension library for Regex
                        // TODO Other validation rules?
                    });
                    if (result.length > 0) {
                        result = "select raise_error(ABORT, s.Error) from (select case " + result + " else null end as Error) s where s.Error is not null;\n";
                    }
                    return result;
                };
                /*
        
                 */
                Driver.prototype.generateInsertValues = function (collectionID, schemaDef) {
                    var result = '';
                    // Iterate through all properties
                    for (var propName in schemaDef.properties) {
                        var p = schemaDef.properties[propName];
                        if (!p.ColumnAssigned) {
                            result += "insert or replace into [Values] ([ObjectID], [ClassID], [PropertyID], [PropIndex], [ctlv], [Value])\n             select (new.ObjectID | (new.HostID << 31)), " + collectionID + ", " + p.PropertyID + ", 0, " + p.ctlv + ", new.[" + p.PropertyName + "]\n             where new.[" + p.PropertyName + "] is not null;\n";
                        }
                    }
                    return result;
                };
                /*
        
                 */
                Driver.prototype.generateDeleteNullValues = function (schemaDef) {
                    var result = '';
                    // Iterate through all properties
                    for (var propName in schemaDef.properties) {
                        var p = schemaDef.properties[propName];
                    }
                    return result;
                };
                Driver.prototype.sync = function (opts, callback) {
                    var self = this;
                    // Wrap all calls into Fibers syncho
                    Sync(function () {
                        try {
                            // Process data and save in .collections and  .schemas tables
                            // Sets .collections ViewOutdated
                            var def = self.generateClassAndSchemaDefForSync(opts);
                            // Regenerate view if needed
                            // Check if class schema needs synchronization
                            if (def.classDef.ViewOutdated !== 1) {
                                callback();
                                return;
                            }
                            var viewSQL = "drop view if exists " + opts.table + ";\n            \ncreate view if not exists " + opts.table + " as select\n            [ObjectID] >> 31 as HostID,\n    ([ObjectID] & 2147483647) as ObjectID,";
                            // Process properties
                            var propIdx = 0;
                            _.forEach(def.classDef.properties, function () {
                            });
                            for (var propName in def.schemaDef.properties) {
                                if (propIdx > 0)
                                    viewSQL += ', ';
                                propIdx++;
                                var p = def.schemaDef.properties[propName];
                                if (p.ColumnAssigned) 
                                // This property is stored directly in .objects table
                                {
                                    viewSQL += "o.[" + p.ColumnAssigned + "] as [" + p.PropertyName + "]\n";
                                }
                                else 
                                // This property is stored in Values table. Need to use subquery for access
                                {
                                    viewSQL += "\n(select v.[Value] from [.values] v\n                    where v.[ObjectID] = o.[ObjectID]\n    and v.[PropIndex] = 0 and v.[PropertyID] = " + p.PropertyID;
                                    if ((p.ctlv & 1) === 1)
                                        viewSQL += " and (v.[ctlv] & 1 = 1)";
                                    viewSQL += ") as [" + p.PropertyName + "]";
                                }
                            }
                            // non-schema properties are returned as single JSON
                            //if (propIdx > 0)
                            //    viewSQL += ', ';
                            //
                            //viewSQL += ` as [.non-schema-props]`;
                            viewSQL += " from [.objects] o\n    where o.[ClassID] = " + def.classDef.ClassID;
                            if (def.classDef.ctloMask !== 0)
                                viewSQL += "and ((o.[ctlo] & " + def.classDef.ctloMask + ") = " + def.classDef.ctloMask + ")";
                            viewSQL += ';\n';
                            // Insert trigger when ObjectID or HostID is null.
                            // In this case, recursively call insert statement with newly obtained ObjectID
                            viewSQL += self.generateTriggerBegin(opts.table, 'insert', 'whenNull', 'when new.[ObjectID] is null or new.[HostID] is null');
                            // Generate new ID
                            viewSQL += "insert or replace into [.generators] (name, seq) select '.objects',\n                coalesce((select seq from [.generators] where name = '.objects') , 0) + 1 ;";
                            viewSQL += "insert into [" + opts.table + "] ([ObjectID], [HostID]";
                            var cols = '';
                            for (var propName in def.schemaDef.properties) {
                                var p = def.schemaDef.properties[propName];
                                viewSQL += ", [" + p.PropertyName + "]";
                                cols += ", new.[" + p.PropertyName + "]";
                            }
                            // HostID is expected to be either (a) ID of another (hosting) object
                            // or (b) 0 or null - means that object will be self-hosted
                            viewSQL += ") select\n            [NextID],\n             case\n                when new.[HostID] is null or new.[HostID] = 0 then [NextID]\n                else new.[HostID]\n             end\n\n             " + cols + " from\n             (SELECT coalesce(new.[ObjectID],\n             (select (seq)\n          FROM [.generators]\n          WHERE name = '.objects' limit 1)) AS [NextID])\n\n             ;\n";
                            viewSQL += "end;\n";
                            // Insert trigger when ObjectID is not null
                            viewSQL += self.generateTriggerBegin(opts.table, 'insert', 'whenNotNull', 'when not (new.[ObjectID] is null or new.[HostID] is null)');
                            viewSQL += self.generateConstraintsForTrigger(opts.table, def.schemaDef);
                            viewSQL += "insert into [.objects] ([ObjectID], [ClassID], [ctlo]";
                            cols = '';
                            for (var propName in def.schemaDef.properties) {
                                var p = def.schemaDef.properties[propName];
                                // if column is assigned
                                if (p.ColumnAssigned) {
                                    viewSQL += ", [" + p.ColumnAssigned + "]";
                                    cols += ", new.[" + p.PropertyName + "]";
                                }
                            }
                            viewSQL += ") values (new.HostID << 31 | (new.ObjectID & 2147483647),\n             " + def.classDef.ClassID + ", " + def.classDef.ctloMask + cols + ");\n";
                            viewSQL += self.generateInsertValues(def.classDef.ClassID, def.schemaDef);
                            viewSQL += 'end;\n';
                            // Update trigger
                            viewSQL += self.generateTriggerBegin(opts.table, 'update');
                            viewSQL += self.generateConstraintsForTrigger(opts.table, def.schemaDef);
                            var columns = '';
                            for (var propName in def.schemaDef.properties) {
                                var p = def.schemaDef.properties[propName];
                                // if column is assigned
                                if (p.ColumnAssigned) {
                                    if (columns !== '')
                                        columns += ',';
                                    columns += "[" + p.ColumnAssigned + "] = new.[" + p.PropertyName + "]";
                                }
                            }
                            if (columns !== '') {
                                viewSQL += "update [.objects] set " + columns + " where [ObjectID] = new.[ObjectID];\n";
                            }
                            viewSQL += self.generateInsertValues(def.classDef.ClassID, def.schemaDef);
                            viewSQL += self.generateDeleteNullValues(def.schemaDef);
                            viewSQL += 'end;\n';
                            // Delete trigger
                            viewSQL += self.generateTriggerBegin(opts.table, 'delete');
                            viewSQL += "delete from [.objects] where [ObjectID] = new.[ObjectID] and [CollectionID] = " + def.classDef.ClassID + ";\n";
                            viewSQL += 'end;\n';
                            console.log(viewSQL);
                            // Run view script
                            self.db.exec.sync(self.db, viewSQL);
                            callback();
                        }
                        catch (err) {
                            console.log(err);
                            // TODO throw err;
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
                    var qry = "select * from [.classes] where [ClassName] = " + opts.table + ";\n    ";
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