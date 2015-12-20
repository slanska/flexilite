import IPropertyDef = Flexilite.models.IPropertyDef;
/**
 * Created by slanska on 03.10.2015.
 */

/// <reference path="../typings/tsd.d.ts"/>

'use strict';

var _ = require("lodash");
import util = require("util");
import sqlite3 = require("sqlite3");
// TODO import sqlquery = require("sql-query");
var Query = require("sql-query").Query;
// TODO var shared = require("./_shared");
// TODO var DDL = require("./DDL/SQL");
var Sync = require("syncho");
import path = require('path');
import ClassDef = require('./models/ClassDef');
import flex = require('./models/index');
import orm = require("orm");
import {link} from "fs";
import {Util} from "./Util";


/*
 Implements Flexilite driver for node-orm.
 Uses SQLite as a backend storage
 */
export class Driver
{
    dialect:string;
    config:any;
    opts:any;
    db:sqlite3.Database;
    aggregate_functions:[string];
    query:any;
    customTypes:any;

    constructor(config, connection:sqlite3.Database, opts)
    {
        this.dialect = 'sqlite';
        this.config = config || {};
        this.opts = opts || {};

        if (!this.config.timezone)
        {
            this.config.timezone = "local";
        }

        this.query = new Query({dialect: this.dialect, timezone: this.config.timezone});
        this.customTypes = {}; // TODO Any custom types?

        if (connection)
        {
            this.db = connection;
        }
        else
        {
            // on Windows, paths have a drive letter which is parsed by
            // url.parse() as the hostname. If host is defined, assume
            // it's the drive letter and add ":"
            var win32 = process.platform == "win32" && config.host && config.host.match(/^[a-z]$/i);

            console.log(config);
            var fn = ((config.host ? (win32 ? config.host + ":" : config.host) : "") + (config.pathname || "")) || ':memory:';

            // SQLITE_OPEN_SHAREDCACHE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_WAL
            this.db = sqlite3.cached.Database(fn, 0x00020000 | sqlite3.OPEN_READWRITE | 0x00080000);
        }

        this.aggregate_functions = ["ABS", "ROUND",
            "AVG", "MIN", "MAX",
            "RANDOM",
            "SUM", "COUNT",
            "DISTINCT"];
    }

    getViewName(table:string):string
    {
        return table;
    }

    convertTimezone(tz:string):any
    {
        if (tz == "Z") return 0;

        var m = tz.match(/([\+\-\s])(\d\d):?(\d\d)?/);
        if (m)
        {
            return (m[1] == '-' ? -1 : 1) * (parseInt(m[2], 10) + ((m[3] ? parseInt(m[3], 10) : 0) / 60)) * 60;
        }
        return false;
    }

// TODO DDL defines standard SQLite sync and drop. Flexilite has custom
// logic for these operations, so DDL should be exluded
// TODO _.extend(Driver.prototype, shared, DDL);
//_.extend(Driver.prototype, shared);

    ping(cb)
    {
        process.nextTick(cb);
        return this;
    }

    on(ev, cb)
    {
        if (ev == "error")
        {
            this.db.on("error", cb);
        }
        return this;
    }

    connect(cb)
    {
        process.nextTick(cb);
    }

    close(cb)
    {
        this.db.close();
        if (typeof cb == "function")
            process.nextTick(cb);
    };

    getQuery()
    {
        return this.query;
    }

    execSimpleQuery(query, cb)
    {
        if (this.opts.debug)
        {
            require("./Debug").sql('sqlite', query);
        }

        // TODO Process query
        this.db.all(query, cb);
    }

    find(fields, table, conditions, opts, cb)
    {
        // TODO Generate query based on arguments
        var q = this.query.select()
            .from(this.getViewName(table)).select(fields);

        if (opts.offset)
        {
            q.offset(opts.offset);
        }
        if (typeof opts.limit == "number")
        {
            q.limit(opts.limit);
        }
        else
            if (opts.offset)
            {
                // OFFSET cannot be used without LIMIT so we use the biggest INTEGER number possible
                q.limit('9223372036854775807');
            }

        if (opts.order)
        {
            for (var i = 0; i < opts.order.length; i++)
            {
                q.order(opts.order[i][0], opts.order[i][1]);
            }
        }

        if (opts.merge)
        {
            q.from(opts.merge.from.table, opts.merge.from.field, opts.merge.to.field).select(opts.merge.select);
            if (opts.merge.where && Object.keys(opts.merge.where[1]).length)
            {
                q = q.where(opts.merge.where[0], opts.merge.where[1], opts.merge.table || null, conditions);
            }
            else
            {
                q = q.where(opts.merge.table || null, conditions);
            }
        }
        else
        {
            q = q.where(conditions);
        }

        if (opts.exists)
        {
            for (var k in opts.exists)
            {
                q.whereExists(opts.exists[k].table, table, opts.exists[k].link, opts.exists[k].conditions);
            }
        }

        q = q.build();

        if (this.opts.debug)
        {
            require("./Debug").sql('sqlite', q);
        }

        // TODO
        this.db.all(q, cb);
    }

    /*

     */
    count(table:string, conditions, opts, cb)
    {
        var q = this.query.select()
            .from(this.getViewName(table))
            .count(null, 'c');

        if (opts.merge)
        {
            q.from(opts.merge.from.table, opts.merge.from.field, opts.merge.to.field);
            if (opts.merge.where && Object.keys(opts.merge.where[1]).length)
            {
                q = q.where(opts.merge.where[0], opts.merge.where[1], conditions);
            }
            else
            {
                q = q.where(conditions);
            }
        }
        else
        {
            q = q.where(conditions);
        }

        if (opts.exists)
        {
            for (var k in opts.exists)
            {
                var opt = opts.exists[k];
                q.whereExists(opt.table, table, opt.link, opt.conditions);
            }
        }

        q = q.build();

        if (this.opts.debug)
        {
            require("./Debug").sql('sqlite', q);
        }
        this.db.all(q, cb);
    }

    /*
     Registers class definition with className based on the sample data.
     proceedExisting flag determines whether data will be processed for already registered
     class. In this case, all additional data attributes that are not registered
     will be registered.
     If proceedExisting === false and class already exists, nothing will happen
     */
    registerClassDefFromObject(className:string, data:any, proceedExisting)
    {
        var classDef = this.getClassDefByName(className, true, true);
    }

    /*
     Private method to generate new sequential object ID.
     Returns int32 value. Must be called within Fiber context.
     */
    private generateObjectID():number
    {
        var self = this;
        (<any>self.db.exec).sync(self.db, `insert or replace into [.generators] (name, seq) select '.objects',
        coalesce((select seq from [.generators] where name = '.objects') , 0) + 1 ;`);

        var objectID:number = (<any>self.db.get).sync(self.db,
            `select seq from [.generators] where name = '.objects' limit 1;`).seq;
        return objectID;
    }

    /*
     Returns fully qualified object ID
     */
    private buildObjectID(objectID:number, hostID:number = null):number
    {
        //
        if (!hostID)
            hostID = objectID;
        return (hostID << 31) | objectID;
    }

    /*
     Iterates through all keys of given data and determines which keys are scalar and defined in class schema.
     Returns object with properties separates into these 2 groups: schema and extra.ß
     */
    private extractSchemaProperties(classDef:IClass, data):IDataToSave
    {
        var result:IDataToSave = {SchemaData: {}, ExtData: {}};
        for (var pi in data)
        {
            var schemaProp = false;
            if (classDef.Properties.hasOwnProperty(pi))
            {
                var v = data[pi];
                if (!_.isObject(v) && !_.isArray(v))
                {
                    //if (_.isDate(v))
                    //v = ;

                    result.SchemaData[pi] = v;
                    schemaProp = true;
                }
            }
            if (!schemaProp)
                result.ExtData[pi] = data[pi];
        }
        return result;
    }

    /*
     Processes individual property. Depending on actual property's value and
     whether it is included in schema, property will be either added to the list of EAV rows
     or to the list to inserted/updated via view
     @param propInfo - data for individual property to be processed
     @param schemaProps - object with all properties which are defined in schema
     @param nonSchemaProps - array of prop definitions which are not defined in class schema
     */
    private processPropertyForSave(propInfo:IPropertyToSave, schemaProps:any, eavItems:IEAVItem[])
    {
        var self = this;

        // Check if property is included into schema
        var schemaProp = propInfo.classDef.Properties[propInfo.propName];

        // Make sure that property is registered as class
        var propClass = schemaProp ? self.getClassDefByID(schemaProp.PropertyID) : self.getClassDefByName(propInfo.propName, true, false);
        var pid = propClass.ClassID.toString();

        function doProp(propIdPrefix:string)
        {
            if (propInfo.propIndex === 0 && schemaProp)
            {
                schemaProps[propInfo.propName] = propInfo.value;
            }
            else
            {
                pid = propIdPrefix + pid;
                eavItems.push({
                    objectID: self.buildObjectID(propInfo.objectID, propInfo.hostID),
                    propID: propClass.ClassID, propIndex: propInfo.propIndex,
                    value: propInfo.value,
                    classID: propClass.ClassID,
                    ctlv: schemaProp ? schemaProp.ctlv : VALUE_CONTROL_FLAGS.NONE
                });
            }
        }

        // Determine actual property type
        if (Buffer.isBuffer(propInfo.value))
        // Binary (BLOB) value. Store as base64 string
        {
            propInfo.value = propInfo.value.toString('base64');
            doProp('X');
        }
        else
            if (_.isDate(propInfo.value))
            // Date value. Store as Julian value (double value)
            {
                propInfo.value = (<Date>propInfo.value).getMilliseconds();
                doProp('D');
            }
            else
                if (_.isArray(propInfo.value))
                // List of properties
                {
                    propInfo.value.forEach(function (item, idx, arr)
                    {
                        var pi:IPropertyToSave = propInfo;
                        pi.propIndex = idx + 1;
                        self.processPropertyForSave(pi, schemaProps, eavItems);
                    });
                }
                else
                    if (_.isObject(propInfo.value))
                    // Reference to another object
                    {
                        var refClassName:string;
                        if (schemaProp)
                        {
                            var refClassID = schemaProp.ReferencedClassID;
                            var refClass = self.getClassDefByID(refClassID);
                            refClassName = refClass.ClassName;
                        }
                        else
                        {
                            refClassName = propInfo.propName;
                        }

                        // TODO Check if object already exists???
                        var refObjectID = self.saveObject(refClassName, propInfo.value, null, propInfo.hostID);
                        eavItems.push({
                            objectID: self.buildObjectID(propInfo.objectID, propInfo.hostID),
                            classID: propInfo.classDef.ClassID,
                            propID: propClass.ClassID,
                            propIndex: 0,
                            ctlv: schemaProp ? schemaProp.ctlv : VALUE_CONTROL_FLAGS.REFERENCE_OWN,
                            value: refObjectID
                        });
                    }
                    else
                    {
                        // Regular scalar property
                        doProp('');
                    }
    }

    /*
     Inserts or updates single object to the database.
     Returns newly generated objectID (for inserted object)
     */
    private saveObject(table:string, data:any, objectID:number, hostID:number):number
    {
        var self = this;

        var classDef = self.getClassDefByName(table, false, true);
        var q = '';

        if (!objectID)
            objectID = self.generateObjectID();
        if (!hostID)
            hostID = objectID;

        var schemaDef:IDataToSave = self.extractSchemaProperties(classDef, data);

        q = self.query.insert()
                .into(this.getViewName(table))
                .set(schemaDef.SchemaData)
                .build() + ';';

        var schemaProps = {};
        var nonSchemaProps:IEAVItem[] = [];

        for (var propName in data)
        {
            // Shortcut to property data
            var v = data[propName];
            var propInfo:IPropertyToSave = {
                objectID: objectID, hostID: hostID, classDef: classDef,
                propName: propName, propIndex: 0, value: v
            };
            self.processPropertyForSave(propInfo, schemaProps, nonSchemaProps);
        }

        (<any>self.db.all).sync(self.db, q);

        nonSchemaProps.forEach(function (item:IEAVItem, idx, arr)
        {
            self.execSQL(`insert or replace into [.values] (ObjectID, ClassID, PropertyID, PropIndex,
                [Value], [ctlv]) values (?, ?, ?, ?, ?, ?)`,
                item.objectID, item.classID, item.propID, item.propIndex, item.value, item.ctlv);
            //TODO Set ctlo. use propInfo?
        });

        if (self.opts.debug)
        {
            require("./Debug").sql('sqlite', q);
        }

        var info = (<any>self.db.all).sync(self.db, q);

        return objectID;
    }

    private execSQL(sql:string, ...args:any[])
    {
        if (args && args.length > 0)
            (<any>this.db.run).sync(sql, args);
        else (<any>this.db.exec).sync(this.db, sql);

    }

    /*

     */
    insert(table:string, data:any, keyProperties, cb)
    {
        if (!keyProperties)
            return cb(null);

        var self = this;
        Sync(function ()
            {
                self.execSQL('savepoint a1;');
                try
                {
                    var objectID = self.saveObject(table, data, null, null);
                    var i, ids = {}, prop;

                    if (keyProperties.length == 1 && keyProperties[0].type == 'serial')
                    {
                        ids[keyProperties[0].name] = objectID;
                    }
                    else
                    {
                        for (i = 0; i < keyProperties.length; i++)
                        {
                            prop = keyProperties[i];
                            ids[prop.name] = data[prop.mapsTo] || null;
                        }
                    }

                    return cb(null, ids);
                }
                catch (err)
                {
                    self.execSQL('rollback;');
                    throw err;
                }
                finally
                {
                    self.execSQL('release a1;');
                }
            }
        );
    }

    /*
     Updates existing data object.
     */
    update(table, changes, conditions, cb)
    {
        var self = this;
        Sync(function ()
        {
            // TODO Iterate via data's properties
            // Props defined in schema, are updated via updatable view
            // Non-schema props are updated/inserted as one batch to Values table
            // TODO Alter where clause to add classID
            var q = self.query.update()
                .into(this.getViewName(table))
                .set(changes)
                .where(conditions)
                .build();

            if (this.opts.debug)
            {
                require("./Debug").sql('sqlite', q);
            }
            self.db.all(q, cb);
        });
    }

    /*

     */
    remove(table, conditions, cb)
    {
        // TODO Alter where clause to add classID
        var q = this.query.remove()
            .from(table)
            .where(conditions)
            .build();

        if (this.opts.debug)
        {
            require("./Debug").sql('sqlite', q);
        }
        this.db.all(q, cb);
    }

    execQuery(qry:string, qryParams:[any], callback)
    {
        if (arguments.length == 2)
        {
            var query = arguments[0];
            var cb = arguments[1];
        }
        else
            if (arguments.length == 3)
            {
                var query = this.query.escape(arguments[0], arguments[1]);
                var cb = arguments[2];
            }
        return this.execSimpleQuery(query, cb);
    }

    /*

     */
    eagerQuery(association, opts, keys, cb)
    {
        var desiredKey:any = Object.keys(association.field);
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
    }

    /*

     */
    clear(table, cb)
    {
        var debug = this.opts.debug;

        this.execQuery("DELETE FROM ??", [this.getViewName(table)], function (err)
        {
            if (err) return cb(err);

            this.execQuery("DELETE FROM ?? WHERE NAME = ?", ['sqlite_sequence', this.getViewName(table)], cb);
        }.bind(this));
    }

    /*

     */
    valueToProperty(value, property)
    {
        var v, customType;

        switch (property.type)
        {
            case "boolean":
                value = !!value;
                break;
            case "object":
                if (typeof value == "object" && !Buffer.isBuffer(value))
                {
                    break;
                }
                try
                {
                    value = JSON.parse(value);
                }
                catch (e)
                {
                    value = null;
                }
                break;

            case "number":
                if (typeof value != 'number' && value !== null)
                {
                    v = Number(value);
                    if (!isNaN(v))
                    {
                        value = v;
                    }
                }
                break;

            case "date":
                if (typeof value == 'string')
                {
                    if (value.indexOf('Z', value.length - 1) === -1)
                    {
                        value = new Date(value + 'Z');
                    }
                    else
                    {
                        value = new Date(value);
                    }

                    if (this.config.timezone && this.config.timezone != 'local')
                    {
                        var tz = this.convertTimezone(this.config.timezone);

                        // shift local to UTC
                        value.setTime(value.getTime() - (value.getTimezoneOffset() * 60000));
                        if (tz !== false)
                        {
                            // shift UTC to timezone
                            value.setTime(value.getTime() - (tz * 60000));
                        }
                    }
                }
                break;

            default:
                customType = this.customTypes[property.type];
                if (customType && 'valueToProperty' in customType)
                {
                    value = customType.valueToProperty(value);
                }
        }
        return value;
    }

    /*
     Converts model property to value
     */
    propertyToValue(value, property)
    {
        var customType;

        switch (property.type)
        {
            case "boolean":
                value = (value) ? 1 : 0;
                break;

            case "object":
                if (value !== null)
                {
                    // FIXME Special processing for Buffer
                    // skip other objects and arrays
                    value = JSON.stringify(value);
                }
                break;

            case "date":
                if (this.config.query && this.config.query.strdates)
                {
                    if (value instanceof Date)
                    {
                        var year = value.getUTCFullYear();
                        var month = value.getUTCMonth() + 1;
                        if (month < 10)
                        {
                            month = '0' + month;
                        }
                        var date = value.getUTCDate();
                        if (date < 10)
                        {
                            date = '0' + date;
                        }
                        var strdate = year + '-' + month + '-' + date;
                        if (property.time === false)
                        {
                            value = strdate;
                            break;
                        }

                        var hours = value.getUTCHours();
                        if (hours < 10)
                        {
                            hours = '0' + hours;
                        }
                        var minutes = value.getUTCMinutes();
                        if (minutes < 10)
                        {
                            minutes = '0' + minutes;
                        }
                        var seconds = value.getUTCSeconds();
                        if (seconds < 10)
                        {
                            seconds = '0' + seconds;
                        }
                        var millis = value.getUTCMilliseconds();
                        if (millis < 10)
                        {
                            millis = '0' + millis;
                        }
                        if (millis < 100)
                        {
                            millis = '0' + millis;
                        }
                        strdate += ' ' + hours + ':' + minutes + ':' + seconds + '.' + millis + '000';
                        value = strdate;
                    }
                }
                break;

            default:
                customType = this.customTypes[property.type];
                if (customType && 'propertyToValue' in customType)
                {
                    value = customType.propertyToValue(value);
                }
        }
        return value;
    }

    /*
     Overrides isSql property for driver
     */
    public    get    isSql()
    {
        return true;
    }

    /*

     */

    /*
     Loads class definition with properties by class ID.
     Class should exist, otherwise exception will be thrown
     */
    private    getClassDefByID(classID:number):IClass
    {
        var classDef = (<any>this.db.get).sync(this.db, 'select * from [.classes] where [ClassID] = ?', classID);
        if (!classDef)
            throw new Error(`Class with id=${classID} not found`);
        classDef.Properties = (<any>this.db.all).sync(this.db, 'select * from [.class_properties] where [ClassID] = ?', classID);
        return classDef;
    }

    /*
     Loads class definition with properties by class name
     If class does not exist yet and createIfNotExist === true, new instance of IClass
     will be created and registered in database.
     If class does not exist and no new class should be registered, class def will
     be created in memory. In this case ClassID will be set to null, Properties - to empty object
     */
    private    getClassDefByName(className:string, createIfNotExist:boolean, loadProperties:boolean):IClass
    {
        var self = this;
        var selStmt = self.db.prepare('select * from [.classes] where [ClassName] = ?');
        var rows = (<any>selStmt.all).sync(selStmt, className);
        var classDef:IClass;

        if (rows.length === 0)
        // Class not found
        {
            if (createIfNotExist)
            {
                var insCStmt = self.db.prepare(
                    `insert or replace into [.classes] ([ClassName], [DBViewName]) values (?, ?);
                    select * from [.classes] where [ClassName] = ?;`);
                (<any>insCStmt.run).sync(insCStmt, [className, className]);

                // Reload class def with all updated properties
                classDef = (<any>selStmt.all).sync(selStmt, className)[0];
            }
            else
            //
            {
                classDef = new ClassDef.Flexilite.models.ClassDef();
                classDef.ClassName = className;
                classDef.DBViewName = this.getViewName(className);
                classDef.ClassID = null;
            }
            classDef.Properties = {};
        }
        else
        {
            classDef = rows[0];
            classDef.Properties = {};
            if (loadProperties)
            // Class found. Try to load properties
            {
                var props = (<any>self.db.all).sync(self.db, 'select * from [.class_properties] where [ClassID] = ?', classDef.ClassID) || {};
                props.forEach(function (p, idx, propArray)
                {
                    classDef.Properties[p.PropertyName] = p;
                });
            }
        }

        return classDef;
    }

    /*
     Synchronizes node-orm model to .classes and .class_properties.
     Makes updates to the database.
     Returns instance of IClass, with all changes applied
     */
    private    syncModelToClassDef(model:ISyncOptions):IClass
    {
        var self = this;

        // Load existing model, if it exists
        var result = this.getClassDefByName(model.table, true, true);

        // Initially set all properties
        var deletedProperties:[string] = <[string]>[];
        for (var propName in result.Properties)
        {
            deletedProperties.push(propName);
        }

        var insCStmt = self.db.prepare(
            `insert or ignore into [.classes] ([ClassName], [DefaultScalarType], [ClassID])
            select ?, ?, (select ClassID from [.classes] where ClassName = ? limit 1);`);

        var insCPStmt = self.db.prepare(`insert or replace into [.class_properties] ([ClassID], [PropertyID],
     [PropertyName], [TrackChanges], [DefaultValue], [DefaultDataType],
     [MinOccurences], [MaxOccurences], [Unique], [MaxLength], [ReferencedClassID],
     [ReversePropertyID], [ColumnAssigned]) values (?,
     (select [ClassID] from [.classes] where [ClassName] = ? limit 1),
      ?, ?, ?, ?,
      ?, ?, ?, ?, ?, ?, ?);`);

        // Check properties
        for (var propName in model.allProperties)
        {
            var pd:IPropertyDef = model.allProperties[propName];

            _.remove(deletedProperties, (value)=> value == propName);

            var cp:IClassProperty = result.Properties[propName.toLowerCase()];
            if (!cp)
            {
                result.Properties[propName.toLowerCase()] = cp = {};
            }
            cp.DefaultDataType = pd.type || cp.DefaultDataType;
            cp.Indexed = pd.indexed || cp.Indexed;
            cp.PropertyName = propName;
            cp.Unique = pd.unique || cp.Unique;
            cp.DefaultValue = pd.defaultValue || cp.DefaultValue;
            var ext = pd.ext || {};

            cp.ColumnAssigned = ext.mappedTo || cp.ColumnAssigned;
            cp.MaxLength = ext.maxLength || cp.MaxLength;
            cp.MaxOccurences = ext.maxOccurences || cp.MaxOccurences;
            cp.MinOccurences = ext.minOccurences || cp.MinOccurences;
            cp.ValidationRegex = ext.validateRegex || cp.ValidationRegex;

            (<any>insCStmt.run).sync(insCStmt, [propName, cp.DefaultDataType, propName]);

            (<any>insCPStmt.run).sync(insCPStmt, [
                result.ClassID,
                propName,
                pd.name,
                (pd.ext && pd.ext.trackChanges) || true,
                pd.defaultValue,
                pd.type || 'text',
                (pd.ext && pd.ext.minOccurences) || 0,
                (pd.ext && pd.ext.maxOccurences) || 1,
                pd.unique || false,
                (pd.ext && pd.ext.maxLength) || 0,
                null,
                null,
                null
            ]);
        }

        result = this.getClassDefByName(model.table, false, true);

        return result;
    }

    /*
     Generates beginning of INSTEAD OF trigger for dynamic view
     */
    private    generateTriggerBegin(viewName:string, triggerKind:string, triggerSuffix = '', when = ''):string
    {
        return `/* Autogenerated code. Do not edit or delete. ${viewName[0].toUpperCase() + viewName.slice(1)}.${triggerKind} trigger*/\n
            drop trigger if exists [trig_${viewName}_${triggerKind}${triggerSuffix}];
    create trigger if not exists [trig_${viewName}_${triggerKind}${triggerSuffix}] instead of ${triggerKind} on [${viewName}]
    for each row\n
    ${when}
    begin\n`;
    }

    /*
     Generates constraints for INSTEAD OF triggers for dynamic view
     */
    private    generateConstraintsForTrigger(classDef:IClass):string
    {
        var result = '';
        // Iterate through all properties
        for (var propName in classDef.Properties)
        {
            var p:IClassProperty = classDef.Properties[propName];

            // Is required/not null?
            if (p.MinOccurences > 0)
                result += `when new.[${p.PropertyName}] is null then '${p.PropertyName} is required'\n`;

            // Is unique
            // TODO Unique in Class.Property, unique in Property (all classes)
            if (p.Unique)
                result += `when exists(select 1 from [${classDef.DBViewName}] v where v.[ObjectID] <> new.[ObjectID]
        and v.[${p.PropertyName}] = new.[${p.PropertyName}]) then '${p.PropertyName} has to be unique'\n`;

            // Range validation

            // Max length validation
            if (p.MaxLength || 0 !== 0)
                result += `when typeof(new.[${p.PropertyName}]) in ('text', 'blob')
        and len(new.[${p.PropertyName}] > ${p.MaxLength}) then 'Length of ${p.PropertyName} exceeds max value of ${p.MaxLength}'\n`;

            // Regex validation
            // TODO Use extension library for Regex

            // TODO Other validation rules?
        }

        if (result.length > 0)
        {
            result = `select raise_error(ABORT, s.Error) from (select case ${result} else null end as Error) s where s.Error is not null`;
        }
        return result;
    }

    /*

     */
    private    generateInsertValues(classDef:IClass):string
    {
        var result = '';

        // Iterate through all properties
        for (var propName in classDef.Properties)
        {
            var p:IClassProperty = classDef.Properties[propName];

            if (!p.ColumnAssigned)
            {
                result += `insert or replace into [Values] ([ObjectID], [ClassID], [PropertyID], [PropIndex], [ctlv], [Value])
             select (new.ObjectID | (new.HostID << 31)), ${classDef.ClassID}, ${p.PropertyID}, 0, ${p.ctlv}, new.[${p.PropertyName}]
             where new.[${p.PropertyName}] is not null;\n`;
            }
        }
        return result;
    }

    /*

     */
    private    generateDeleteNullValues(classDef:IClass):string
    {
        var result = '';

        // Iterate through all properties
        for (var propName in classDef.Properties)
        {
            var p:IClassProperty = classDef.Properties[propName];
            //
            //if (!p.ColumnAssigned)
            //{
            //    result += `delete from [.values] where [ObjectID] = (old.ObjectID | (old.HostID << 31)) and [PropertyID] = ${p.PropertyID}
            //    and [PropIndex] = 0 and [ClassID] = ${classDef.ClassID} and new.[${p.PropertyName}] is not null;\n`;
            //}
        }
        return result;
    }

    sync(opts:ISyncOptions, callback)
    {
        var self = this;

        Sync(function ()
        {
            try
            {
                // Process data and save in .classes and .class_properties
                // Set Flag SchemaOutdated
                var classDef:IClass = self.syncModelToClassDef(opts);

                // Regenerate view
                // Check if class schema needs synchronization
                if (classDef.SchemaOutdated !== 1)
                {
                    callback();
                    return;
                }

                var viewSQL = `drop view if exists ${classDef.DBViewName};
            \ncreate view if not exists ${classDef.DBViewName} as select
            [ObjectID] >> 31 as HostID,
    ([ObjectID] & 2147483647) as ObjectID,`;
                // Process properties
                var propIdx = 0;
                for (var propName in classDef.Properties)
                {
                    if (propIdx > 0)
                        viewSQL += ', ';
                    propIdx++;
                    var p:IClassProperty = classDef.Properties[propName];
                    if (p.ColumnAssigned && p.ColumnAssigned !== null)
                    // This property is stored directly in .objects table
                    {
                        viewSQL += `o.[${p.ColumnAssigned}] as [${p.PropertyName}]\n`;
                    }
                    else
                    // This property is stored in Values table. Need to use subquery for access
                    {
                        viewSQL += `\n(select v.[Value] from [.values] v
                    where v.[ObjectID] = o.[ObjectID]
    and v.[PropIndex] = 0 and v.[PropertyID] = ${p.PropertyID}`;
                        if ((p.ctlv & 1) === 1)
                            viewSQL += ` and (v.[ctlv] & 1 = 1)`;
                        viewSQL += `) as [${p.PropertyName}]`;
                    }
                }

                // non-schema properties are returned as single JSON
                if (propIdx > 0)
                    viewSQL += ', ';

                viewSQL += ` as [.non-schema-props]`;

                viewSQL += ` from [.objects] o
    where o.[ClassID] = ${classDef.ClassID}`;

                if (classDef.ctloMask !== 0)
                    viewSQL += `and ((o.[ctlo] & ${classDef.ctloMask}) = ${classDef.ctloMask})`;

                viewSQL += ';\n';

                // Insert trigger when ObjectID or HostID is null.
                // In this case, recursively call insert statement with newly obtained ObjectID
                viewSQL += self.generateTriggerBegin(classDef.DBViewName, 'insert', 'whenNull',
                    'when new.[ObjectID] is null or new.[HostID] is null');

                // Generate new ID
                viewSQL += `insert or replace into [.generators] (name, seq) select '.objects',
                coalesce((select seq from [.generators] where name = '.objects') , 0) + 1 ;`;
                viewSQL += `insert into [${classDef.DBViewName}] ([ObjectID], [HostID]`;

                var cols = '';
                for (var propName in classDef.Properties)
                {
                    var p:IClassProperty = classDef.Properties[propName];
                    viewSQL += `, [${p.PropertyName}]`;
                    cols += `, new.[${p.PropertyName}]`;
                }

                // HostID is expected to be either (a) ID of another (hosting) object
                // or (b) 0 or null - means that object will be self-hosted
                viewSQL += `) select
            [NextID],
             case
                when new.[HostID] is null or new.[HostID] = 0 then [NextID]
                else new.[HostID]
             end

             ${cols} from
             (SELECT coalesce(new.[ObjectID],
             (select (seq)
          FROM [.generators]
          WHERE name = '.objects' limit 1)) AS [NextID])

             ;\n`;
                viewSQL += `end;\n`;

                // Insert trigger when ObjectID is not null
                viewSQL += self.generateTriggerBegin(classDef.DBViewName, 'insert', 'whenNotNull',
                    'when not (new.[ObjectID] is null or new.[HostID] is null)');
                viewSQL += self.generateConstraintsForTrigger(classDef);

                viewSQL += `insert into [.objects] ([ObjectID], [ClassID], [ctlo]`;
                cols = '';
                for (var propName in classDef.Properties)
                {
                    var p:IClassProperty = classDef.Properties[propName];

                    // if column is assigned
                    if (p.ColumnAssigned)
                    {
                        viewSQL += `, [${p.ColumnAssigned}]`;
                        cols += `, new.[${p.PropertyName}]`;
                    }
                }

                viewSQL += `) values (new.HostID << 31 | (new.ObjectID & 2147483647),
             ${classDef.ClassID}, ${classDef.ctloMask}${cols});\n`;

                viewSQL += self.generateInsertValues(classDef);
                viewSQL += 'end;\n';

                // Update trigger
                viewSQL += self.generateTriggerBegin(classDef.DBViewName, 'update');
                viewSQL += self.generateConstraintsForTrigger(classDef);

                var columns = '';
                for (var propName in classDef.Properties)
                {
                    var p:IClassProperty = classDef.Properties[propName];

                    // if column is assigned
                    if (p.ColumnAssigned)
                    {
                        if (columns !== '')
                            columns += ',';
                        columns += `[${p.ColumnAssigned}] = new.[${p.PropertyName}]`;
                    }
                }
                if (columns !== '')
                {
                    viewSQL += `update [.objects] set ${columns} where [ObjectID] = new.[ObjectID];\n`;
                }

                viewSQL += self.generateInsertValues(classDef);
                viewSQL += self.generateDeleteNullValues(classDef);
                viewSQL += 'end;\n';

                // Delete trigger
                viewSQL += self.generateTriggerBegin(classDef.DBViewName, 'delete');
                viewSQL += `delete from [.objects] where [ObjectID] = new.[ObjectID] and [ClassID] = ${classDef.ClassID};\n`;
                viewSQL += 'end;\n';

                console.log(viewSQL);

                // Run view script
                (<any>self.db.exec).sync(self.db, viewSQL);

                callback();
            }
            catch (err)
            {
                console.log(err);
                callback(err);
            }
        });
    }

// TODO Implement drop
    drop(opts:IDropOptions, callback)
    {
        //table - The name of the table
        //properties
        //one_associations
        //many_associations

        var qry = `select * from [.classes] where [ClassName] = ${opts.table};
    `;
        this.db.exec(qry);

        // TODO Delete objects?
        callback();
    }

    hasMany(Model, association:IHasManyAssociation)
    {
        // TODO Process relations
        return {
            has: function (Instance, Associations, conditions, cb)
            {
                cb();
            },
            get: function (Instance, conditions, options, createInstance, cb)
            {
                cb();
            },
            add: function (Instance, Association, data, cb)
            {
                cb();
            },
            del: function (Instance, Associations, cb)
            {
                cb();
            }

        };
    }
}

// Register Flexilite driver
(<any>orm).addAdapter('flexilite', Driver);