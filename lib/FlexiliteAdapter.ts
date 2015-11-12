/**
 * Created by slanska on 03.10.2015.
 */

/// <reference path="../typings/tsd.d.ts"/>

//module FlexiliteDB
//{

var _ = require("lodash");
import util = require("util");
import sqlite3 = require("sqlite3");
var Query = require("sql-query").Query;
var shared = require("./_shared");
var DDL = require("./DDL/SQL");
var wait = require('wait.for');

//exports = Driver;
module.exports = Driver;

class _Driver
{
    db:sqlite3.Database;

    /*

     */
    constructor(public config, connection, public opts)
    {
        this.db = connection;


    }
}

function Driver(config, connection:sqlite3.Database, opts)
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

        // TODO Test how cached works
        // TODO new??

        this.db = sqlite3.cached.Database(((config.host ? (win32 ? config.host + ":" : config.host) : "") + (config.pathname || "")) || ':memory:');

    }

    // Add special version of prepare function to confirm wait.for declaration
    if (!this.db.__proto__.prepareStatement)
    {
        this.db.__proto__.prepareStatement = function (sql, stdCallback)
        {
            var stmt = this.prepare(sql, function (err)
            {
                return stdCallback(err, stmt);
            });
        };
    }

    this.aggregate_functions = ["ABS", "ROUND",
        "AVG", "MIN", "MAX",
        "RANDOM",
        "SUM", "COUNT",
        "DISTINCT"];
}

// TODO DDL defines standard SQL sync and drop. Flexilite has custom
// logic for these operations, so DDL should be exluded
// TODO _.extend(Driver.prototype, shared, DDL);
_.extend(Driver.prototype, shared);

Driver.prototype.ping = function (cb)
{
    process.nextTick(cb);
    return this;
};

Driver.prototype.on = function (ev, cb)
{
    if (ev == "error")
    {
        this.db.on("error", cb);
    }
    return this;
};

Driver.prototype.connect = function (cb)
{
    process.nextTick(cb);
};

Driver.prototype.close = function (cb)
{
    this.db.close();
    if (typeof cb == "function")
        process.nextTick(cb);
};

Driver.prototype.getQuery = function ()
{
    return this.query;
};

Driver.prototype.execSimpleQuery = function (query, cb)
{
    if (this.opts.debug)
    {
        require("./Debug").sql('sqlite', query);
    }

    // TODO Process query
    this.db.all(query, cb);
};

Driver.prototype.find = function (fields, table, conditions, opts, cb)
{
    // TODO Generate query based on arguments
    var q = this.query.select()
        .from(table).select(fields);

    //var tableName = 'Orders';
    //this.query.select().from('Objects').where();
    //var sql = `select * from [${tableName}] `;

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
};

Driver.prototype.count = function (table, conditions, opts, cb)
{
    var q = this.query.select()
        .from(table)
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
            q.whereExists(opts.exists[k].table, table, opts.exists[k].link, opts.exists[k].conditions);
        }
    }

    q = q.build();

    if (this.opts.debug)
    {
        require("./Debug").sql('sqlite', q);
    }
    this.db.all(q, cb);
};

/*

 */
Driver.prototype.insert = function (table, data, keyProperties, cb)
{
    // TODO Iterate via data's properties
    // Props defined in schema, are inserted via updatable view
    // Non-schema props are inserted as one batch to Values table
    var q = this.query.insert()
        .into(table)
        .set(data)
        .build();

    if (this.opts.debug)
    {
        require("./Debug").sql('sqlite', q);
    }

    this.db.all(q, function (err, info)
    {
        if (err)
            return cb(err);
        if (!keyProperties)
            return cb(null);

        var i, ids = {}, prop;

        // TODO Reload automatically generated values (IDs etc.)
        if (keyProperties.length == 1 && keyProperties[0].type == 'serial')
        {
            // TODO Get last inserted ID
            this.db.get("SELECT last_insert_rowid() AS last_row_id",
                function (err, row)
                {
                    if (err) return cb(err);

                    ids[keyProperties[0].name] = row.last_row_id;

                    return cb(null, ids);
                });
        }
        else
        {
            for (i = 0; i < keyProperties.length; i++)
            {
                prop = keyProperties[i];
                ids[prop.name] = data[prop.mapsTo] || null;
            }
            return cb(null, ids);
        }
    }.bind(this));
};

/*

 */
Driver.prototype.update = function (table, changes, conditions, cb)
{
    // TODO Iterate via data's properties
    // Props defined in schema, are updated via updatable view
    // Non-schema props are updated/inserted as one batch to Values table
    // TODO Alter where clause to add classID
    var q = this.query.update()
        .into(table)
        .set(changes)
        .where(conditions)
        .build();

    if (this.opts.debug)
    {
        require("./Debug").sql('sqlite', q);
    }
    this.db.all(q, cb);
};

/*

 */
Driver.prototype.remove = function (table, conditions, cb)
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
};

/*

 */
Driver.prototype.clear = function (table, cb)
{
    var debug = this.opts.debug;

    this.execQuery("DELETE FROM ??", [table], function (err)
    {
        if (err) return cb(err);

        this.execQuery("DELETE FROM ?? WHERE NAME = ?", ['sqlite_sequence', table], cb);
    }.bind(this));
};

/*

 */
Driver.prototype.valueToProperty = function (value, property)
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
                    var tz = convertTimezone(this.config.timezone);

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
};

/*

 */
Driver.prototype.propertyToValue = function (value, property)
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
};

/*

 */
Object.defineProperty(Driver.prototype, "isSql", {
    value: true
});

function convertTimezone(tz:string):any
{
    if (tz == "Z") return 0;

    var m = tz.match(/([\+\-\s])(\d\d):?(\d\d)?/);
    if (m)
    {
        return (m[1] == '-' ? -1 : 1) * (parseInt(m[2], 10) + ((m[3] ? parseInt(m[3], 10) : 0) / 60)) * 60;
    }
    return false;
}


// TODO Implement sync
interface ISyncOptions
{
    extension:any;
    id:any;
    table:string;
    properties:[any];
    allProperties:[string, Flexilite.models.IPropertyDef];
    indexes:[any];
    customTypes:[any];
    one_associations:[any];
    many_associations:[any];
    extend_associations:[any];
}

/*
 Internal method for synchronizing class properties
 */
Driver.prototype.syncProperties = function (opts:ISyncOptions, classID:number, callback)
{
    var self = this;

    var insCStmt = self.db.prepare(`insert or ignore into [Classes] ([ClassName]) values (?);`);
var selCPStmt = self.db.prepare(`select [ClassID] from [Classes] where [ClassName] = ? limit 1`);
    var insCPStmt = self.db.prepare(`insert  into [ClassProperties] ([ClassID], [PropertyID],
     [PropertyName], [TrackChanges], [DefaultValue], [DefaultDataType],
     [MinOccurences], [MaxOccurences], [Unique], [MaxLength], [ReferencedClassID],
     [ReversePropertyID]) values (?,
     (select [ClassID] from [Classes] where [ClassName] = ? limit 1),
      ?, ?, ?, ?,
      ?, ?, ?, ?, ?, ?);`);

    for (var key in opts.allProperties)
    {
        var pd:Flexilite.models.IPropertyDef = opts.allProperties[key];
        var propName = (pd.ext && pd.ext.mappedTo) || pd.name;
        wait.forMethod(insCStmt, "run", [propName]);
        var clsProp = wait.forMethod(selCPStmt, "get", [propName]);
        console.log(`ClassID: ${classID}, PropertyID: ${clsProp.ClassID}, Name: ${propName}`);
        wait.forMethod(insCPStmt, "run", [
            classID,
            propName,
            pd.name,
            (pd.ext && pd.ext.trackChanges) || true,
            pd.defaultValue,
            pd.type || 'text',
            (pd.ext && pd.ext.minOccurences) || 0,
            (pd.ext && pd.ext.maxOccurences) || 1,
            pd.unique || false,
            (pd.ext && pd.ext.maxLength) || -1,
            null,
            null
        ]);

        console.log(`${pd.name} processed`);
    }

    //callback();
};

Driver.prototype.sync = function (opts:ISyncOptions, callback)
{
    var self = this;

    if (global.alreadyInSync === true)
        return ;

    global.alreadyInSync = true;

    wait.launchFiber(function ()
    {
        try
        {
            //
            // Process data and save in Classes and ClassProperties
            // Set Flag SchemaOutdated
            // Run view regeneration process

            var classDef = {
                ClassID: 0, // TODO
                ClassName: opts.table,
                SchemaID: 0, // TODO
                SystemClass: false,
                DefaultScalarType: "string",
                //TitlePropertyID: number;
                //SubTitleProperty: number;
                //SchemaXML: string;
                SchemaOutdated: true,
                MinOccurences: 0,
                MaxOccurences: 1 << 31,
                DBViewName: `vw_${opts.table}`,
                ctloMask: 0,

                Properties: []
            };

            var getClassSQL = `select * from [Classes] where [ClassName] = '${opts.table}';`;
            var getClsStmt = self.db.prepare('select * from [Classes] where [ClassName] = ?;');
            var insClsStmt = self.db.prepare(
                `insert or replace into [Classes] ([ClassName],
    [SchemaOutdated], [DBViewName])
    values (?, ?, ?);`);
            var cls = wait.forMethod(self.db, "get", getClassSQL);

            if (!cls)
            // Class not found. Insert new record
            {
                var rslt = wait.forMethod(insClsStmt, "run", [opts.table, true, `vw_${opts.table}`]);
                cls = wait.forMethod(self.db, "get", getClassSQL);
            }

            wait.forMethod(self, "syncProperties", opts, cls.ClassID);

            // Regenerate view
            var viewSQL = `create view if not exists ${classDef.DBViewName} as select `;
// Process properties
            viewSQL += ` from [Objects] where [ClassID] = ${classDef.ClassID} and
    ([]);`;
            viewSQL += `-- Insert trigger
    create trigger [trig_${classDef.DBViewName}_insert] instead of insert
    begin
        insert or replace into [Objects] ([ClassID], [ctlo]) values (${classDef.ClassID}, );

-- Loop on properties
        insert or replace into [Values] ([ClassID], [ObjectID], [PropertyID], [PropIndex],
        [ctlv], [Value]) values ();
    end;`;

            viewSQL += `create trigger [trig_${classDef.DBViewName}_update] instead of update
    begin
    end;`;

            viewSQL += `create trigger [trig_${classDef.DBViewName}_delete] instead of delete
    begin
    end;`;


            callback();
        }
        catch (err)
        {
            console.log(err);
            callback(err);
        }
        finally
        {
            global.alreadyInSync = false;
        }

    });
};

interface IDropOptions
{
    table :string;
    properties:[any];
    one_associations:[any];
    many_associations:[any];
}

// TODO Implement drop
Driver.prototype.drop = function (opts:IDropOptions, callback)
{
    //table - The name of the table
    //properties
    //one_associations
    //many_associations

    var qry = `select * from [Classes] where [ClassName] = ${opts.table}`;
    this.db.exec(qry);
    var sql = `delete from [Classes] where [ClassName]='${opts.table}'`;

    callback();
};

Driver.prototype.hasMany = function (Model, association)
{
    return {
        has: function (Instance, Associations, conditions, cb)
        {
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
};
//}

