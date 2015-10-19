/**
 * Created by Ruslan Skorynin on 03.10.2015.
 */

/// <reference path="../node_modules/orm/lib/TypeScript/orm.d.ts"/>
/// <reference path="../node_modules/orm/lib/TypeScript/sql-query.d.ts"/>
/// <reference path="../typings/node/node.d.ts"/>

//module FlexiliteDB
//{
    var _ = require("lodash");
    var util = require("util");
    var sqlite3 = require("sqlite3");
    var Query = require("sql-query").Query;
    var shared = require("./_shared");
    var DDL = require("./DDL/SQL");

//exports = Driver;
module.exports = Driver;

    class _Driver
    {
        db:any;
        constructor(public config,  connection, public opts)
        {
            this.db = connection;
        }
    }

     function Driver(config, connection, opts)
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
            if (process.platform == "win32" && config.host && config.host.match(/^[a-z]$/i))
            {
                // TODO Test how cached works
                this.db = new sqlite3.cached.Database(((config.host ? config.host + ":" : "") + (config.pathname || "")) || ':memory:');
            }
            else
            {
                this.db = new sqlite3.cached.Database(((config.host ? config.host : "") + (config.pathname || "")) || ':memory:');
            }
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
        this.db.all(query, cb);
    };

    Driver.prototype.find = function (fields, table, conditions, opts, cb)
    {
        var q = this.query.select()
            .from(table).select(fields);

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

    Driver.prototype.clear = function (table, cb)
    {
        var debug = this.opts.debug;

        this.execQuery("DELETE FROM ??", [table], function (err)
        {
            if (err) return cb(err);

            this.execQuery("DELETE FROM ?? WHERE NAME = ?", ['sqlite_sequence', table], cb);
        }.bind(this));
    };

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
                } catch (e)
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
    Driver.prototype.sync = function (opts, cb)
    {
        //extension
        //id
        //table
        //properties
        //allProperties
        //indexes
        //customTypes
        //one_associations
        //many_associations
        //extend_associations
        cb();
    };

    // TODO Implement drop
    Driver.prototype.drop = function (opts, cb)
    {
        //table - The name of the table
        //properties
        //one_associations
        //many_associations
        cb();
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
