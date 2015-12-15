/**
 * Created by slanska on 03.10.2015.
 */
/// <reference path="../typings/tsd.d.ts"/>
'use strict';
var _ = require("lodash");
var sqlite3 = require("sqlite3");
// TODO import sqlquery = require("sql-query");
var Query = require("sql-query").Query;
// TODO var shared = require("./_shared");
// TODO var DDL = require("./DDL/SQL");
var Sync = require("syncho");
var ClassDef = require('./models/ClassDef');
var orm = require("orm");
/*
 Implements Flexilite driver for node-orm.
 Uses SQLite as a backend storage
 */
var Driver = (function () {
    function Driver(config, connection, opts) {
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
            // SQLITE_OPEN_SHAREDCACHE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_WAL
            this.db = sqlite3.cached.Database(fn, 0x00020000 | sqlite3.OPEN_READWRITE | 0x00080000);
        }
        this.aggregate_functions = ["ABS", "ROUND",
            "AVG", "MIN", "MAX",
            "RANDOM",
            "SUM", "COUNT",
            "DISTINCT"];
    }
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
        if (typeof cb == "function")
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
     Registers class definition with className based on the sample data.
     proceedExisting flag determines whether data will be processed for already registered
     class. In this case, all additional data attributes that are not registered
     will be registered.
     If proceedExisting === false and class already exists, nothing will happen
     */
    Driver.prototype.registerClassDefFromObject = function (className, data, proceedExisting) {
        var classDef = this.getClassDefByName(className, true, true);
    };
    /*
     Prepares object data to be inserted or updated.
     During preparation, attribute names for extended data are replaced with attribute IDs
     */
    Driver.prototype.preprocessObjectData = function (classDef, data) {
        var result = { SchemaData: {}, ExtData: {}, LinkedSchemaObjects: {} };
        // Props defined in schema will be inserted/updated via updatable view
        // Non schema data are inserted as EAV records
        for (var propName in data) {
            var v = data[propName];
            if (!classDef.Properties.hasOwnProperty(propName)) 
            // Non-schema props are inserted as one batch to Values table
            {
                // Make sure that property is registered as class
                var propClass = this.getClassDefByName(propName, true, false);
                var pid = propClass.ClassID.toString();
                if (Buffer.isBuffer(v)) {
                    v = v.toString('base64');
                    pid = 'X' + pid;
                }
                else if (_.isDate(v)) {
                    v = v.getMilliseconds();
                    pid = 'D' + pid;
                }
                else if (_.isObject(v)) {
                    // Another object found. It will be processed recursively
                    result.LinkedSchemaObjects[propName] = v;
                }
                else if (_.isArray(v)) {
                }
                else {
                    result.ExtData[pid] = v;
                }
            }
            else {
                if (_.isObject(v) && !Buffer.isBuffer(v) && !_.isDate(v))
                    result.LinkedSchemaObjects[propName] = v;
                else
                    result.SchemaData[propName] = v;
            }
        }
        return result;
    };
    /*
     Private method to generate new sequential object ID.
     Returns int32 value. Must be called within Fiber context.
     */
    Driver.prototype.generateObjectID = function () {
        var self = this;
        self.db.exec.sync(self.db, "insert or replace into [.generators] (name, seq) select '.objects',\n        coalesce((select seq from [.generators] where name = '.objects') , 0) + 1 ;");
        var objectID = self.db.get.sync(self.db, "select seq from [.generators] where name = '.objects' limit 1;").seq;
        return objectID;
    };
    /*
     Inserts individual object to the database.
     Returns newly generated objectID
     */
    Driver.prototype.insertObject = function (table, data, hostID) {
        var self = this;
        var classDef = self.getClassDefByName(table, false, true);
        var q = '';
        var objectID = self.generateObjectID();
        if (!hostID)
            hostID = objectID;
        var objData = this.preprocessObjectData(classDef, data);
        // Add ID attributes
        objData.SchemaData.HostID = hostID;
        objData.SchemaData.ObjectID = objectID;
        // If there is schema-defined data
        if (!_.isEmpty(objData.SchemaData))
            q = self.query.insert()
                .into(this.getViewName(table))
                .set(objData.SchemaData)
                .build() + ';' + q;
        if (!_.isEmpty(objData.LinkedSchemaObjects)) {
            for (var linkName in objData.LinkedSchemaObjects) {
                // Depending on class and property definition,
                var linkHostID = hostID;
                var linkClassName;
                // Try to find out if there is link property
                if (classDef.Properties.hasOwnProperty(linkName)) {
                    var linkProp = classDef.Properties[linkName];
                    var linkClass = self.getClassDefByID(linkProp.ReferencedClassID);
                    linkClassName = linkClass.ClassName;
                }
                else {
                    linkClassName = linkName;
                }
                var linkedResult = self.insertObject(linkClassName, objData.LinkedSchemaObjects[linkName], linkHostID);
                // Add reference to created object
                self.execSQL("insert into [.values] (ObjectID, ClassID, PropertyID, PropIndex,\n                ) values (?, ?)");
            }
        }
        //q += this.query.insert().into('[.values]').set(
        //    {
        //        ClassID: classDef.ClassID,
        //        ObjectID: objectID,
        //        Value: data[propName]
        //
        //    });
        if (self.opts.debug) {
            require("./Debug").sql('sqlite', q);
        }
        var info = self.db.all.sync(self.db, q);
        return objectID;
    };
    Driver.prototype.execSQL = function (sql) {
        var args = [];
        for (var _i = 1; _i < arguments.length; _i++) {
            args[_i - 1] = arguments[_i];
        }
        this.db.exec.sync(this.db, sql, args);
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
                var objectID = self.insertObject(table, data, null);
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
                return cb(null, ids);
            }
            catch (err) {
                self.execSQL('rollback;');
                throw err;
            }
            finally {
                self.execSQL('release a1;');
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
                    value = JSON.stringify(value);
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

     */
    /*
     Loads class definition with properties by class ID.
     Class should exist, otherwise exception will be thrown
     */
    Driver.prototype.getClassDefByID = function (classID) {
        var classDef = this.db.get.sync(this.db, 'select * from [.classes] where [ClassID] = ?', classID);
        if (!classDef)
            throw new Error("Class with id=" + classID + " not found");
        classDef.Properties = this.db.all.sync(this.db, 'select * from [.class_properties] where [ClassID] = ?', classID);
        return classDef;
    };
    /*
     Loads class definition with properties by class name
     If class does not exist yet and createIfNotExist === true, new instance of IClass
     will be created and registered in database.
     If class does not exist and no new class should be registered, class def will
     be created in memory. In this case ClassID will be set to null, Properties - to empty object
     */
    Driver.prototype.getClassDefByName = function (className, createIfNotExist, loadProperties) {
        var self = this;
        var selStmt = self.db.prepare('select * from [.classes] where [ClassName] = ?');
        var rows = selStmt.all.sync(selStmt, className);
        var classDef;
        if (rows.length === 0) 
        // Class not found
        {
            if (createIfNotExist) {
                var insCStmt = self.db.prepare("insert or replace into [.classes] ([ClassName], [DBViewName]) values (?, ?);\n                    select * from [.classes] where [ClassName] = ?;");
                insCStmt.run.sync(insCStmt, [className, className]);
                // Reload class def with all updated properties
                classDef = selStmt.all.sync(selStmt, className)[0];
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
        else {
            classDef = rows[0];
            classDef.Properties = {};
            if (loadProperties) 
            // Class found. Try to load properties
            {
                var props = self.db.all.sync(self.db, 'select * from [.class_properties] where [ClassID] = ?', classDef.ClassID) || {};
                props.forEach(function (p, idx, propArray) {
                    classDef.Properties[p.PropertyName] = p;
                });
            }
        }
        return classDef;
    };
    /*
     Synchronizes node-orm model to .classes and .class_properties.
     Makes updates to the database.
     Returns instance of IClass, with all changes applied
     */
    Driver.prototype.syncModelToClassDef = function (model) {
        var self = this;
        // Load existing model, if it exists
        var result = this.getClassDefByName(model.table, true, true);
        // Initially set all properties
        var deletedProperties = [];
        for (var propName in result.Properties) {
            deletedProperties.push(propName);
        }
        var insCStmt = self.db.prepare("insert or ignore into [.classes] ([ClassName], [DefaultScalarType], [ClassID])\n            select ?, ?, (select ClassID from [.classes] where ClassName = ? limit 1);");
        var insCPStmt = self.db.prepare("insert or replace into [.class_properties] ([ClassID], [PropertyID],\n     [PropertyName], [TrackChanges], [DefaultValue], [DefaultDataType],\n     [MinOccurences], [MaxOccurences], [Unique], [MaxLength], [ReferencedClassID],\n     [ReversePropertyID], [ColumnAssigned]) values (?,\n     (select [ClassID] from [.classes] where [ClassName] = ? limit 1),\n      ?, ?, ?, ?,\n      ?, ?, ?, ?, ?, ?, ?);");
        // Check properties
        for (var propName in model.allProperties) {
            var pd = model.allProperties[propName];
            _.remove(deletedProperties, function (value) { return value == propName; });
            var cp = result.Properties[propName.toLowerCase()];
            if (!cp) {
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
            insCStmt.run.sync(insCStmt, [propName, cp.DefaultDataType, propName]);
            insCPStmt.run.sync(insCPStmt, [
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
    Driver.prototype.generateConstraintsForTrigger = function (classDef) {
        var result = '';
        // Iterate through all properties
        for (var propName in classDef.Properties) {
            var p = classDef.Properties[propName];
            // Is required/not null?
            if (p.MinOccurences > 0)
                result += "when new.[" + p.PropertyName + "] is null then '" + p.PropertyName + " is required'\n";
            // Is unique
            // TODO Unique in Class.Property, unique in Property (all classes)
            if (p.Unique)
                result += "when exists(select 1 from [" + classDef.DBViewName + "] v where v.[ObjectID] <> new.[ObjectID]\n        and v.[" + p.PropertyName + "] = new.[" + p.PropertyName + "]) then '" + p.PropertyName + " has to be unique'\n";
            // Range validation
            // Max length validation
            if (p.MaxLength || 0 !== 0)
                result += "when typeof(new.[" + p.PropertyName + "]) in ('text', 'blob')\n        and len(new.[" + p.PropertyName + "] > " + p.MaxLength + ") then 'Length of " + p.PropertyName + " exceeds max value of " + p.MaxLength + "'\n";
        }
        if (result.length > 0) {
            result = "select raise_error(ABORT, s.Error) from (select case " + result + " else null end as Error) s where s.Error is not null";
        }
        return result;
    };
    /*

     */
    Driver.prototype.generateInsertValues = function (classDef) {
        var result = '';
        // Iterate through all properties
        for (var propName in classDef.Properties) {
            var p = classDef.Properties[propName];
            if (!p.ColumnAssigned) {
                result += "insert or replace into [Values] ([ObjectID], [ClassID], [PropertyID], [PropIndex], [ctlv], [Value])\n             select (new.ObjectID | (new.HostID << 31)), " + classDef.ClassID + ", " + p.PropertyID + ", 0, " + p.ctlv + ", new.[" + p.PropertyName + "]\n             where new.[" + p.PropertyName + "] is not null;\n";
            }
        }
        return result;
    };
    /*

     */
    Driver.prototype.generateDeleteNullValues = function (classDef) {
        var result = '';
        // Iterate through all properties
        for (var propName in classDef.Properties) {
            var p = classDef.Properties[propName];
        }
        return result;
    };
    Driver.prototype.sync = function (opts, callback) {
        var self = this;
        Sync(function () {
            try {
                // Process data and save in .classes and .class_properties
                // Set Flag SchemaOutdated
                var classDef = self.syncModelToClassDef(opts);
                // Regenerate view
                // Check if class schema needs synchronization
                if (classDef.SchemaOutdated !== 1) {
                    callback();
                    return;
                }
                var viewSQL = "drop view if exists " + classDef.DBViewName + ";\n            \ncreate view if not exists " + classDef.DBViewName + " as select\n            [ObjectID] >> 31 as HostID,\n    ([ObjectID] & 2147483647) as ObjectID,";
                // Process properties
                var propIdx = 0;
                for (var propName in classDef.Properties) {
                    if (propIdx > 0)
                        viewSQL += ', ';
                    propIdx++;
                    var p = classDef.Properties[propName];
                    if (p.ColumnAssigned && p.ColumnAssigned !== null) 
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
                if (propIdx > 0)
                    viewSQL += ', ';
                viewSQL += " as [.non-schema-props]";
                viewSQL += " from [.objects] o\n    where o.[ClassID] = " + classDef.ClassID;
                if (classDef.ctloMask !== 0)
                    viewSQL += "and ((o.[ctlo] & " + classDef.ctloMask + ") = " + classDef.ctloMask + ")";
                viewSQL += ';\n';
                // Insert trigger when ObjectID or HostID is null.
                // In this case, recursively call insert statement with newly obtained ObjectID
                viewSQL += self.generateTriggerBegin(classDef.DBViewName, 'insert', 'whenNull', 'when new.[ObjectID] is null or new.[HostID] is null');
                // Generate new ID
                viewSQL += "insert or replace into [.generators] (name, seq) select '.objects',\n                coalesce((select seq from [.generators] where name = '.objects') , 0) + 1 ;";
                viewSQL += "insert into [" + classDef.DBViewName + "] ([ObjectID], [HostID]";
                var cols = '';
                for (var propName in classDef.Properties) {
                    var p = classDef.Properties[propName];
                    viewSQL += ", [" + p.PropertyName + "]";
                    cols += ", new.[" + p.PropertyName + "]";
                }
                // HostID is expected to be either (a) ID of another (hosting) object
                // or (b) 0 or null - means that object will be self-hosted
                viewSQL += ") select\n            [NextID],\n             case\n                when new.[HostID] is null or new.[HostID] = 0 then [NextID]\n                else new.[HostID]\n             end\n\n             " + cols + " from\n             (SELECT coalesce(new.[ObjectID],\n             (select (seq)\n          FROM [.generators]\n          WHERE name = '.objects' limit 1)) AS [NextID])\n\n             ;\n";
                viewSQL += "end;\n";
                // Insert trigger when ObjectID is not null
                viewSQL += self.generateTriggerBegin(classDef.DBViewName, 'insert', 'whenNotNull', 'when not (new.[ObjectID] is null or new.[HostID] is null)');
                viewSQL += self.generateConstraintsForTrigger(classDef);
                viewSQL += "insert into [.objects] ([ObjectID], [ClassID], [ctlo]";
                cols = '';
                for (var propName in classDef.Properties) {
                    var p = classDef.Properties[propName];
                    // if column is assigned
                    if (p.ColumnAssigned) {
                        viewSQL += ", [" + p.ColumnAssigned + "]";
                        cols += ", new.[" + p.PropertyName + "]";
                    }
                }
                viewSQL += ") values (new.HostID << 31 | (new.ObjectID & 2147483647),\n             " + classDef.ClassID + ", " + classDef.ctloMask + cols + ");\n";
                viewSQL += self.generateInsertValues(classDef);
                viewSQL += 'end;\n';
                // Update trigger
                viewSQL += self.generateTriggerBegin(classDef.DBViewName, 'update');
                viewSQL += self.generateConstraintsForTrigger(classDef);
                var columns = '';
                for (var propName in classDef.Properties) {
                    var p = classDef.Properties[propName];
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
                viewSQL += self.generateInsertValues(classDef);
                viewSQL += self.generateDeleteNullValues(classDef);
                viewSQL += 'end;\n';
                // Delete trigger
                viewSQL += self.generateTriggerBegin(classDef.DBViewName, 'delete');
                viewSQL += "delete from [.objects] where [ObjectID] = new.[ObjectID] and [ClassID] = " + classDef.ClassID + ";\n";
                viewSQL += 'end;\n';
                console.log(viewSQL);
                // Run view script
                self.db.exec.sync(self.db, viewSQL);
                callback();
            }
            catch (err) {
                console.log(err);
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
})();
exports.Driver = Driver;
// Register Flexilite driver
orm.addAdapter('flexilite', Driver);
//# sourceMappingURL=FlexiliteAdapter.js.map