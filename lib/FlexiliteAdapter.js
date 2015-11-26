/**
 * Created by slanska on 03.10.2015.
 */
/// <reference path="../typings/tsd.d.ts"/>
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
        var js = this.db.all.sync(this.db, "select json_set('{}', '$.a', 99, '$.c', 'sdsd', '$.ff', 100, null, 4);");
        this.aggregate_functions = ["ABS", "ROUND",
            "AVG", "MIN", "MAX",
            "RANDOM",
            "SUM", "COUNT",
            "DISTINCT"];
    }
    Driver.prototype.getViewName = function (table) {
        return "vw_" + table;
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

     */
    Driver.prototype.insert = function (table, data, keyProperties, cb) {
        // TODO Iterate via data's properties
        // Props defined in schema, are inserted via updatable view
        // Non-schema props are inserted as one batch to Values table
        var q = this.query.insert()
            .into(this.getViewName(table)) // TODO
            .set(data)
            .build();
        if (this.opts.debug) {
            require("./Debug").sql('sqlite', q);
        }
        this.db.all(q, function (err, info) {
            if (err)
                return cb(err);
            if (!keyProperties)
                return cb(null);
            var i, ids = {}, prop;
            // TODO Reload automatically generated values (IDs etc.)
            if (keyProperties.length == 1 && keyProperties[0].type == 'serial') {
                // TODO Get last inserted ID
                this.db.get("SELECT last_insert_rowid() AS last_row_id", function (err, row) {
                    if (err)
                        return cb(err);
                    ids[keyProperties[0].name] = row.last_row_id;
                    return cb(null, ids);
                });
            }
            else {
                for (i = 0; i < keyProperties.length; i++) {
                    prop = keyProperties[i];
                    ids[prop.name] = data[prop.mapsTo] || null;
                }
                return cb(null, ids);
            }
        }.bind(this));
    };
    /*

     */
    Driver.prototype.update = function (table, changes, conditions, cb) {
        // TODO Iterate via data's properties
        // Props defined in schema, are updated via updatable view
        // Non-schema props are updated/inserted as one batch to Values table
        // TODO Alter where clause to add classID
        var q = this.query.update()
            .into(this.getViewName(table))
            .set(changes)
            .where(conditions)
            .build();
        if (this.opts.debug) {
            require("./Debug").sql('sqlite', q);
        }
        this.db.all(q, cb);
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
     Loads class definition with properties by class ID
     */
    Driver.prototype.getClassDef = function (self, classID) {
        var classDef = self.db.get.sync(self.db, 'select * from [Classes] where [ClassID] = ?', classID);
        classDef.Properties = self.db.all.sync(self.db, 'select * from [ClassProperties] where [ClassID] = ?', classID);
        return classDef;
    };
    /*
     Returns instance of IClassDef converted from node ORM model definition
     */
    Driver.prototype.OrmModelToClassDef = function (model) {
        var result = new ClassDef.Flexilite.models.ClassDef();
        result.ClassName = model.table;
        result.DBViewName = this.getViewName(model.table);
        result.Properties = {};
        for (var propName in model) {
        }
        return result;
    };
    /*
     Internal method for synchronizing class properties
     */
    Driver.prototype.syncProperties = function (opts, classID) {
        var self = this;
        var existingClassDef = self.getClassDefByID(self, classID);
        var insCStmt = self.db.prepare("insert or ignore into [Classes] ([ClassName]) values (?);");
        var insCPStmt = self.db.prepare("insert or replace into [ClassProperties] ([ClassID], [PropertyID],\n     [PropertyName], [TrackChanges], [DefaultValue], [DefaultDataType],\n     [MinOccurences], [MaxOccurences], [Unique], [MaxLength], [ReferencedClassID],\n     [ReversePropertyID], [ColumnAssigned]) values (?,\n     (select [ClassID] from [Classes] where [ClassName] = ? limit 1),\n      ?, ?, ?, ?,\n      ?, ?, ?, ?, ?, ?, ?);");
        for (var key in opts.allProperties) {
            var pd = opts.allProperties[key];
            var propName = (pd.ext && pd.ext.mappedTo) || pd.name;
            insCStmt.run.sync(insCStmt, [propName]);
            insCPStmt.run.sync(insCPStmt, [
                classID,
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
        insCStmt.finalize.sync(insCStmt);
        insCPStmt.finalize.sync(insCPStmt);
        return self.getClassDefByID(self, classID);
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
                // Process data and save in Classes and ClassProperties
                // Set Flag SchemaOutdated
                // Run view regeneration process
                var getClassSQL = "select * from [Classes] where [ClassName] = '" + opts.table + "';";
                var cls = self.db.get.sync(self.db, getClassSQL);
                if (!cls) 
                // Class not found. Insert new record
                {
                    var insClsStmt = self.db.prepare("insert or replace into [Classes] ([ClassName],\n    [SchemaOutdated], [DBViewName])\n    values (?, ?, ?);");
                    var rslt = insClsStmt.run.sync(insClsStmt, [opts.table, true, self.getViewName(opts.table)]);
                    cls = self.db.get.sync(self.db, getClassSQL);
                    insClsStmt.finalize.sync(insClsStmt);
                }
                var classDef = self.syncProperties(opts, cls.ClassID);
                // Regenerate view
                var viewSQL = "drop view if exists " + classDef.DBViewName + ";\n            \ncreate view if not exists " + classDef.DBViewName + " as select\n            [ObjectID] >> 31 as HostID,\n    ([ObjectID] & 2147483647) as ObjectID,";
                // Process properties
                var propIdx = 0;
                for (var propName in classDef.Properties) {
                    if (propIdx > 0)
                        viewSQL += ', ';
                    propIdx++;
                    var p = classDef.Properties[propName];
                    if (p.ColumnAssigned && p.ColumnAssigned !== null) 
                    // This property is stored directly in Objects table
                    {
                        viewSQL += "o.[" + p.ColumnAssigned + "] as [" + p.PropertyName + "]\n";
                    }
                    else 
                    // This property is stored in Values table. Need to use subquery for access
                    {
                        viewSQL += "\n(select v.[Value] from [Values] v\n                    where v.[ObjectID] = o.[ObjectID]\n    and v.[PropIndex] = 0 and v.[PropertyID] = " + p.PropertyID;
                        if ((p.ctlv & 1) === 1)
                            viewSQL += " and (v.[ctlv] & 1 = 1)";
                        viewSQL += ") as [" + p.PropertyName + "]";
                    }
                }
                viewSQL += " from [Objects] o\n    where o.[ClassID] = " + classDef.ClassID;
                if (classDef.ctloMask !== 0)
                    viewSQL += "and ((o.[ctlo] & " + classDef.ctloMask + ") = " + classDef.ctloMask + ")";
                viewSQL += ';\n';
                // Insert trigger when ObjectID or HostID is null.
                // In this case, recursively call insert statement with newly obtained ObjectID
                viewSQL += self.generateTriggerBegin(classDef.DBViewName, 'insert', 'whenNull', 'when new.[ObjectID] is null or new.[HostID] is null');
                viewSQL += "insert into [" + classDef.DBViewName + "] ([ObjectID], [HostID]";
                var cols = '';
                for (var propName in classDef.Properties) {
                    var p = classDef.Properties[propName];
                    viewSQL += ", [" + p.PropertyName + "]";
                    cols += ", new.[" + p.PropertyName + "]";
                }
                // HostID is expected to be either (a) ID of another (hosting) object
                // or (b) 0 or null - means that object will be self-hosted
                viewSQL += ") select\n            [NextID],\n             case\n                when new.[HostID] is null or new.[HostID] = 0 then [NextID]\n                else new.[HostID]\n             end\n\n             " + cols + " from\n             (SELECT coalesce(new.[ObjectID] & 2147483647,\n             (select ([seq] & 2147483647) + 1\n          FROM [sqlite_sequence]\n          WHERE name = 'Objects' limit 1)) AS [NextID])\n\n             ;\n";
                viewSQL += "end;\n";
                // Insert trigger when ObjectID is not null
                viewSQL += self.generateTriggerBegin(classDef.DBViewName, 'insert', 'whenNotNull', 'when not (new.[ObjectID] is null or new.[HostID] is null)');
                viewSQL += self.generateConstraintsForTrigger(classDef);
                viewSQL += "insert into [Objects] ([ObjectID], [ClassID], [ctlo]";
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
                    viewSQL += "update [Objects] set " + columns + " where [ObjectID] = new.[ObjectID];\n";
                }
                viewSQL += self.generateInsertValues(classDef);
                viewSQL += self.generateDeleteNullValues(classDef);
                viewSQL += 'end;\n';
                // Delete trigger
                viewSQL += self.generateTriggerBegin(classDef.DBViewName, 'delete');
                viewSQL += "delete from [Objects] where [ObjectID] = new.[ObjectID] and [ClassID] = " + classDef.ClassID + ";\n";
                viewSQL += 'end;\n';
                console.log(viewSQL);
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
        var qry = "select * from [Classes] where [ClassName] = " + opts.table + ";\n    ";
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