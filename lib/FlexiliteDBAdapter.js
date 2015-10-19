/**
 * Created by Ruslan Skorynin on 20.06.2015.
 */
var __extends = (this && this.__extends) || function (d, b) {
    for (var p in b) if (b.hasOwnProperty(p)) d[p] = b[p];
    function __() { this.constructor = d; }
    d.prototype = b === null ? Object.create(b) : (__.prototype = b.prototype, new __());
};
// TS references
///<reference path="../typings/node/node.d.ts"/>
///<reference path="../typings/sqlite3/sqlite3.d.ts"/>
///<reference path="../typings/lodash/lodash.d.ts"/>
///<reference path="../d.ts/jugglingdb/jugglingdb.d.ts"/>
var sqlite3 = require('sqlite3');
var util = require("util");
var Flexilite;
(function (Flexilite) {
    var jugglingdb = require("jugglingdb");
    //import safeRequire = require('utils').safeRequire;
    //var BaseSQL = require('../sql');
    var FlexiliteDB = (function (_super) {
        __extends(FlexiliteDB, _super);
        function FlexiliteDB(schema, client /*sqlite3.SQLite3*/) {
            var _this = this;
            _super.call(this);
            this.schema = schema;
            this.client = client;
            this.name = 'flexilite';
            /*
            List of all registered data models ("tables")
             */
            // TODO Dictionary/Array of AbstractClass
            this._models = {};
            this.escape = function (value) {
                return '"' + _this.escape(value) + '"';
            };
            // model, fields, indexes, done
            this.alterTable = function (model, actualFields, indexes, done, checkOnly) {
                if (checkOnly === void 0) { checkOnly = false; }
                var self = _this;
                var m = self._models[model];
                var defIndexes = m.settings.indexes;
                var propNames = Object.keys(m.properties);
                var sql = [], isql = [];
                var reBuild = false;
                // change/add new fields
                propNames.forEach(function (propName) {
                    if (propName === 'id') {
                        return;
                    }
                    var found;
                    actualFields.forEach(function (f) {
                        if (f.name === propName) {
                            found = f;
                        }
                    });
                    if (found) {
                        actualize(propName, found);
                    }
                    else {
                        if (m.properties[propName] !== false) {
                            sql.push('ADD COLUMN `' + propName + '` ' + self.propertySettingsSQL(model, propName));
                        }
                    }
                });
                // drop columns
                actualFields.forEach(function (f) {
                    var notFound = !~propNames.indexOf(f.name);
                    if (f.name === 'id') {
                        return;
                    }
                    if (notFound || !m.properties[f.name]) {
                        reBuild = true;
                    }
                });
                for (var fieldName in m.properties) {
                    var idx = m.properties[fieldName];
                    if ('undefined' !== typeof idx['index']
                        || 'undefined' !== typeof idx['unique']) {
                        var foundKey = false, UNIQ = '', kuniq = !idx['unique'] ? 0 : idx['unique'], ikey = (model + '_' + fieldName).toString();
                        kuniq = kuniq === false ? 0 : 1;
                        if (idx['index'] !== false) {
                            indexes.forEach(function (index) {
                                if (ikey === index.name) {
                                    if (index.unique !== kuniq) {
                                        UNIQ = kuniq === 1 ? ' UNIQUE ' : '';
                                        isql.push('DROP INDEX `' + ikey + '`;');
                                        // isql.push('CREATE ' + UNIQ + ' INDEX `' + ikey + '` ON ' + self.tableEscaped(model) + ' (`' + fieldName + '` ASC);');
                                        reBuild = true;
                                    }
                                    foundKey = index.name;
                                }
                            });
                            if (!foundKey) {
                                UNIQ = 'undefined' !== typeof m.properties[fieldName]['unique'] ? ' UNIQUE ' : '';
                                isql.push('CREATE ' + UNIQ + ' INDEX `' + ikey + '` ON ' + self.tableEscaped(model) + ' (`' + fieldName + '` ASC);');
                            }
                        }
                        else {
                            reBuild = true;
                        }
                    }
                }
                if (defIndexes) {
                    for (var fieldName in defIndexes) {
                        var foundKey = false, ikey = (model + '_' + fieldName).toString();
                        indexes.forEach(function (index) {
                            if (ikey === index.name) {
                                foundKey = index.name;
                            }
                        });
                        if (!foundKey) {
                            var fields = [], columns = defIndexes[fieldName]['columns'] || [];
                            if (Object.prototype.toString.call(columns) === '[object Array]') {
                                fields = columns;
                            }
                            else if (typeof columns === 'string') {
                                columns = (columns || '').replace(',', ' ').split(/\s+/);
                            }
                            if (columns.length) {
                                columns = columns.map(function (column) {
                                    return '`' + column + '` ASC';
                                });
                                var UNIQ = 'undefined' !== typeof defIndexes[fieldName]['unique'] ? ' UNIQUE ' : '';
                                isql.push('CREATE ' + UNIQ + ' INDEX `' + ikey + '` ON ' + self.tableEscaped(model) + ' (' + columns.join(',') + ');');
                            }
                        }
                    }
                }
                var tSql = [];
                if (sql.length) {
                    tSql.push('ALTER TABLE ' + self.tableEscaped(model) + ' ' + sql.join(',\n'));
                }
                if (isql.length) {
                    tSql = tSql.concat(isql);
                }
                if (tSql.length) {
                    if (checkOnly) {
                        return done(null, true, {
                            statements: tSql,
                            query: ''
                        });
                    }
                    else {
                        var tlen = tSql.length;
                        tSql.forEach(function (tsql) {
                            return self.command(tsql, function (err) {
                                if (err)
                                    console.log(err);
                                if (--tlen === 0) {
                                    if (reBuild) {
                                        return rebuid(model, m.properties, actualFields, indexes, done);
                                    }
                                    else {
                                        return done();
                                    }
                                }
                            });
                        });
                    }
                }
                else {
                    if (checkOnly) {
                        return done(null, reBuild, {
                            statements: tSql,
                            query: ''
                        });
                    }
                    else {
                        if (reBuild) {
                            return rebuid(model, m.properties, actualFields, indexes, done);
                        }
                        else {
                            return done && done();
                        }
                    }
                }
                function actualize(propName, oldSettings) {
                    var newSettings = m.properties[propName];
                    if (newSettings && changed(newSettings, oldSettings)) {
                        reBuild = true;
                    }
                }
                function changed(newSettings, oldSettings) {
                    var dflt_value = (newSettings.default || null);
                    var notnull = (newSettings.null === false ? 1 : 0);
                    if (oldSettings.notnull !== notnull
                        || oldSettings.dflt_value !== dflt_value) {
                        return true;
                    }
                    return (oldSettings.type.toUpperCase() !== self.datatype(newSettings));
                }
                function rebuid(model, oldSettings, newSettings, indexes, done) {
                    var nsst = [];
                    if (newSettings) {
                        newSettings.forEach(function (newSetting) {
                            if (oldSettings[newSetting.name] !== false) {
                                nsst.push(newSetting.name);
                            }
                        });
                    }
                    var rbSql = 'ALTER TABLE `' + model + '` RENAME TO `tmp_' + model + '`;';
                    var inSql = 'INSERT INTO `' + model + '` (' + nsst.join(',') + ') '
                        + 'SELECT ' + nsst.join(',') + ' FROM `tmp_' + model + '`;';
                    var dpSql = 'DROP TABLE `tmp_' + model + '`;';
                    return self.command(rbSql, function (err) {
                        if (err)
                            console.log(err);
                        return self.createTable(model, indexes, function (err) {
                            if (err)
                                console.log(err);
                            return self.command(inSql, function (err) {
                                if (err)
                                    console.log(err);
                                return self.command(dpSql, function () {
                                    self.createIndexes(model, self._models[model], done);
                                });
                            });
                        });
                    });
                }
            };
            // TODO
        }
        /*
        Returns escaped table name for the given model
         */
        FlexiliteDB.prototype.tableEscaped = function (model) {
            return this.escapeName(this.table(model));
        };
        /*
        Returns table name for the given model
         */
        FlexiliteDB.prototype.table = function (model) {
            return this._models[model].model.tableName;
        };
        FlexiliteDB.prototype.initialize = function (schema, callback) {
            if (!sqlite3) {
                return;
            }
            sqlite3.verbose();
            var s = schema.settings;
            var Database = sqlite3.Database;
            schema.client = new Database(s.database);
            schema.adapter = new FlexiliteDB(schema, schema.client);
            schema.client.run('PRAGMA encoding = "UTF-8"', function () {
                // TODO Process migrate
                if (s.database === ':memory:') {
                    schema.adapter.automigrate(callback);
                }
                else {
                    // TODO automigrate() ???
                    process.nextTick(callback);
                }
            });
        };
        FlexiliteDB.prototype.command = function (sql, queryParamsOrCallback, callback) {
            this.query('run', [].slice.call(arguments));
        };
        FlexiliteDB.prototype.execSql = function () {
            this.query('exec', [].slice.call(arguments));
        };
        FlexiliteDB.prototype.queryAll = function (sql, callbackOrQueryParams, callback) {
            this.query('all', [].slice.call(arguments));
        };
        FlexiliteDB.prototype.queryOne = function (sql, callback) {
            this.client.get();
            this.query('get', [].slice.call(arguments));
        };
        FlexiliteDB.prototype.query = function (method, args) {
            var time = Date.now();
            var log; // TODO = super.log;
            var cb = args.pop();
            if (typeof cb === 'function') {
                args.push(function (err, data) {
                    if (log)
                        log(args[0], time);
                    cb.call(this, err, data);
                });
            }
            else {
                args.push(cb);
                args.push(function (err, data) {
                    log(args[0], time);
                });
            }
            this.client[method].apply(this.client, args);
        };
        FlexiliteDB.prototype.save = function (model, data, callback) {
            var queryParams = [];
            // TODO Build view UPDATE query for view-level attributes
            var sql = 'UPDATE ' + this.tableEscaped(model.modelName) + ' SET ' +
                Object.keys(data).map(function (key) {
                    queryParams.push(data[key]);
                    return key + ' = ?';
                }).join(', ') + ' WHERE id = ' + data.id;
            this.command(sql, queryParams, function (err) {
                // TODO Process other properties (not defined in view)
                // INSERT OR REPLACE INTO Values () VALUES ();
                if (callback)
                    callback(err);
            });
        };
        /**
         * Must invoke callback(err, id)
         * @param {Object} model
         * @param {Object} data
         * @param {Function} callback
         */
        FlexiliteDB.prototype.create = function (model, data, callback) {
            data = data || {};
            var questions = [];
            var values = Object.keys(data).map(function (key) {
                questions.push('?');
                return data[key];
            });
            // TODO Insert view-defined attributes
            var sql = 'INSERT INTO ' + this.tableEscaped(model.modelName) + ' (' + Object.keys(data).join(',') + ') VALUES (';
            sql += questions.join(',');
            sql += ')';
            this.command(sql, values, function (err) {
                // TODO Insert other class-defined and undefined attrubutes
                callback(err, this && this.lastID);
            });
        };
        FlexiliteDB.prototype.updateOrCreate = function (model, data, callback) {
            data = data || {};
            var questions = [];
            var values = Object.keys(data).map(function (key) {
                questions.push('?');
                return data[key];
            });
            var sql = util.format('INSERT OR REPLACE INTO [%s] (%s) VALUES (', this.tableEscaped(model), Object.keys(data).join(','));
            sql += questions.join(',');
            sql += ')';
            this.command(sql, values, function (err) {
                if (!err && this) {
                    data.id = this.lastID;
                }
                callback(err, data);
            });
        };
        /**
         * Update rows
         * @param {String} model
         * @param {Object} filter
         * @param {Object} data
         * @param {Function} callback
         */
        FlexiliteDB.prototype.update = function (model, filter, data, callback) {
            if ('function' === typeof filter) {
                return filter(new Error("Get parametrs undefined"), null);
            }
            if ('function' === typeof data) {
                return data(new Error("Set parametrs undefined"), null);
            }
            filter = filter.where ? filter.where : filter;
            var self = this;
            var combined = [];
            //TODO
            var props;
            Object.keys(data).forEach(function (key) {
                if (props[key] || key === 'id') {
                    var k = '`' + key + '`';
                    var v;
                    if (key !== 'id') {
                        v = self.toDatabase(props[key], data[key]);
                    }
                    else {
                        v = data[key];
                    }
                    combined.push(k + ' = ' + v);
                }
            });
            var sql = 'UPDATE ' + self.tableEscaped(model.modelName);
            sql += ' SET ' + combined.join(', ');
            sql += ' ' + self.buildWhere(filter, self, model);
            // TODO
            var queryParams;
            self.command(sql, queryParams, function (err, affected) {
                callback(err, affected);
            });
        };
        FlexiliteDB.prototype.toFields = function (model, data) {
            var self = this, fields = [];
            var props = this._models[model].properties;
            Object.keys(data).forEach(function (key) {
                if (props[key]) {
                    fields.push('`' + key.replace(/\./g, '`.`') + '` = ' + self.toDatabase(props[key], data[key]));
                }
            }.bind(self));
            return fields.join(',');
        };
        /*

         */
        FlexiliteDB.prototype.toDatabase = function (prop, val) {
            if (val === null) {
                return 'NULL';
            }
            if (val.constructor.name === 'Object') {
                var operator = Object.keys(val)[0];
                val = val[operator];
                if (operator === 'between') {
                    if (prop.type.name === 'Date') {
                        return 'strftime(' + this.toDatabase(prop, val[0]) + ')' +
                            ' AND strftime(' +
                            this.toDatabase(prop, val[1]) + ')';
                    }
                    else {
                        return this.toDatabase(prop, val[0]) +
                            ' AND ' +
                            this.toDatabase(prop, val[1]);
                    }
                }
                else if (operator === 'in' || operator === 'inq' || operator === 'nin') {
                    if (!(val.propertyIsEnumerable('length')) && typeof val === 'object' && typeof val.length === 'number') {
                        for (var i = 0; i < val.length; i++) {
                            val[i] = this.escape(val[i]);
                        }
                        return val.join(',');
                    }
                    else {
                        return val;
                    }
                }
            }
            if (!prop)
                return val;
            if (prop.type.name === 'Number' || prop.type.name === 'Integer' || prop.type.name === 'Real')
                return val;
            if (prop.type.name === 'Date') {
                if (!val) {
                    return 'NULL';
                }
                if (!val.toUTCString) {
                    val = new Date(val).getTime();
                }
                else if (val.getTime) {
                    val = val.getTime();
                }
                return val;
            }
            if (prop.type.name === "Boolean") {
                return val ? 1 : 0;
            }
            val = val.toString();
            return this.escape(val);
        };
        FlexiliteDB.prototype.fromDatabase = function (model, data) {
            var self = this;
            if (!data) {
                return null;
            }
            var props = self._models[model].properties;
            Object.keys(data).forEach(function (key) {
                var val = data[key];
                if (props[key]) {
                    data[key] = val;
                }
            });
            return data;
        };
        FlexiliteDB.escapeName = function (name) {
            return '`' + name + '`';
        };
        FlexiliteDB.prototype.exists = function (model, id, callback) {
            var sql = 'SELECT 1 FROM ' + this.tableEscaped(model) + ' WHERE id = ' + id + ' LIMIT 1';
            this.queryOne(sql, function (err, data) {
                if (err)
                    return callback(err);
                callback(null, data && data['1'] === 1);
            });
        };
        FlexiliteDB.prototype.findById = function (model, id, callback) {
            var sql = util.format("select * from [%s] where [id]=%d limit 1", this.tableEscaped(model.modelName), id);
            //var sql = 'SELECT * FROM ' + this.tableEscaped(model) + ' WHERE id = ' + id + ' LIMIT 1';
            this.queryOne(sql, function (err, data) {
                if (data) {
                    data.id = id;
                }
                else {
                    data = null;
                }
                callback(err, this.fromDatabase(model, data));
            }.bind(this));
        };
        FlexiliteDB.prototype.all = function (model, filter, callback) {
            if ('function' === typeof filter) {
                callback = filter;
                filter = {};
            }
            if (!filter) {
                filter = {};
            }
            var sql = 'SELECT * FROM ' + this.tableEscaped(model);
            var self = this;
            var queryParams = [];
            if (filter) {
                if (filter.where) {
                    sql += ' ' + this.buildWhere(filter.where, self, model);
                }
                if (filter.order) {
                    sql += ' ' + this.buildOrderBy(filter.order);
                }
                if (filter.group) {
                    sql += ' ' + self.buildGroupBy(filter.group);
                }
                if (filter.limit) {
                    sql += ' ' + this.buildLimit(filter.limit, filter.skip || 0);
                }
            }
            this.queryAll(sql, queryParams, function (err, data) {
                if (err) {
                    return callback(err, []);
                }
                callback(null, data.map(function (obj) {
                    return self.fromDatabase(model, obj);
                }));
            }.bind(this));
            return sql;
        };
        FlexiliteDB.prototype.disconnect = function () {
            this.client.close();
        };
        FlexiliteDB.prototype.autoupdate = function (cb) {
            var self = this;
            var wait = 0;
            Object.keys(this._models).forEach(function (model) {
                wait += 1;
                self.queryAll('PRAGMA TABLE_INFO(' + self.tableEscaped(model) + ');', function (err, fields) {
                    self.queryAll('PRAGMA INDEX_LIST(' + self.tableEscaped(model) + ');', function (err, indexes) {
                        if (!err && fields.length) {
                            self.alterTable(model, fields, indexes, done);
                        }
                        else {
                            self.createTable(model, indexes, done);
                        }
                    });
                });
            });
            function done(err) {
                if (err) {
                    console.log(err);
                }
                if (--wait === 0 && cb) {
                    cb(err);
                }
            }
        };
        FlexiliteDB.buildCreateClassSQL = function (className, isSystemClass) {
            if (isSystemClass === void 0) { isSystemClass = false; }
            var sql = util.format("insert or replace into [%s] Classes ([ClassName], [SystemClass]) values ('%s');", className, isSystemClass);
            return sql;
        };
        FlexiliteDB.prototype.createTable = function (model, indexes, done) {
            var self = this;
            var className = self.tableEscaped(model);
            var sql = FlexiliteDB.buildCreateClassSQL(className, model.isSystemClass);
            // TODO Handle SystemClass attribute
            // Process class properties
            for (var prop in model.properties) {
                var propClassName = self.tableEscaped(prop.name);
                var ctlo = 0; // TODO
                var ctloMask = 0; // TODO
                sql += util.format(FlexiliteDB.buildCreateClassSQL(propClassName) +
                    "insert or replace into [ClassProperties] ([ClassID], [PropertyID], [TrackChanges], " +
                    "[ctlo], [ctloMask], [DefaultDataType], [MinOccurences], [MaxOccurences]," +
                    "[Unique], [MaxLength]) values ((select ClassID from Classes where ClassName = '%s')," +
                    "(select ClassID from Classes where ClassName='%s'), %d, %d, %d, '%s', %d, %d, %d, %d)", className, propClassName, prop.trackChanges, ctlo, ctloMask, prop.defaultDataType, prop.minOccurence, prop.maxOccurence);
            }
            self.client.exec();
        };
        FlexiliteDB.prototype.isActual = function (cb) {
            var ok = false;
            var self = this;
            var wait = 0;
            Object.keys(this._models).forEach(function (model) {
                wait += 1;
                self.queryAll('PRAGMA TABLE_INFO(' + self.tableEscaped(model) + ')', function (err, fields) {
                    self.queryAll('PRAGMA INDEX_LIST(' + self.tableEscaped(model) + ')', function (err, indexes) {
                        if (!err && fields.length) {
                            self.alterTable(model, fields, indexes, done, true);
                        }
                    });
                });
            });
            function done(err, needAlter) {
                if (err) {
                    console.log(err);
                }
                ok = ok || needAlter;
                if (--wait === 0 && cb) {
                    cb(null, !ok);
                }
            }
        };
        /**
         * Create multi column index callback(err, index)
         * @param {Object} model
         * @param {Object} fields
         * @param {Object} params
         * @param {Function} callback
         */
        FlexiliteDB.prototype.ensureIndex = function (model, fields, params, done) {
            var self = this, sql = "", keyName = params.name || null, afld = [], kind = "";
            Object.keys(fields).forEach(function (field) {
                if (!keyName) {
                    keyName = model + '_' + field;
                }
                afld.push('`' + field + '` ASC');
            });
            if (params.unique) {
                kind = "UNIQUE";
            }
            sql += 'CREATE ' + kind + ' INDEX `' + keyName + '` ON ' + self.tableEscaped(model.modelName) + ' (' + afld.join(', ') + ')';
            self.command(sql, done);
        };
        FlexiliteDB.prototype.datatype = function (p) {
            switch (p.type.name) {
                case 'String':
                    return 'VARCHAR(' + (p.limit || 255) + ')';
                case 'Text':
                case 'JSON':
                    return 'TEXT';
                case 'Number':
                    return 'INT(11)';
                case 'Date':
                    return 'DATETIME';
                case 'Boolean':
                    return 'TINYINT(1)';
            }
        };
        /**
         * Create index callback(err, index)
         * @param {Object} model
         * @param {Object} fields
         * @param {Object} params
         * @param {Function} callback
         */
        FlexiliteDB.prototype.createIndexes = function (model, props, done) {
            var self = this, sql = [], m = props, s = m.settings;
            for (var fprop in m.properties) {
                var idx = m.properties[fprop];
                if ('undefined' !== typeof idx['index']
                    || 'undefined' !== typeof idx['unique']) {
                    if (idx['index'] !== false) {
                        var UNIQ = 'undefined' !== typeof m.properties[fprop]['unique'] ? ' UNIQUE ' : '';
                        sql.push('CREATE ' + UNIQ + ' INDEX `' + model + '_' + fprop + '` ON ' + self.tableEscaped(model) + ' (`' + fprop + '` ASC)');
                    }
                }
            }
            if (s.indexes) {
                for (var tprop in s.indexes) {
                    var fields = [], columns = s.indexes[tprop]['columns'] || [];
                    if (Object.prototype.toString.call(columns) === '[object Array]') {
                        fields = columns;
                    }
                    else if (typeof columns === 'string') {
                        columns = (columns || '').replace(',', ' ').split(/\s+/);
                    }
                    if (columns.length) {
                        columns = columns.map(function (column) {
                            return '`' + column + '` ASC';
                        });
                        var UNIQ = 'undefined' !== typeof s.indexes[tprop]['unique'] ? ' UNIQUE ' : '';
                        sql.push(' CREATE ' + UNIQ + ' INDEX `' + model + '_' + tprop + '` ON ' + self.tableEscaped(model) + ' (' + columns.join(', ') + ')');
                    }
                }
            }
            if (sql.length) {
                var tsqls = sql.length;
                sql.forEach(function (query) {
                    self.command(query, function () {
                        if (--tsqls === 0)
                            done();
                    });
                });
            }
            else {
                done();
            }
        };
        FlexiliteDB.prototype.propertiesSQL = function (model) {
            var self = this;
            var sql = [];
            Object.keys(self._models[model].properties).forEach(function (prop) {
                if (prop === 'id') {
                    return;
                }
                if (self._models[model].properties[prop] !== false) {
                    return sql.push('`' + prop + '` ' + self.propertySettingsSQL(model, prop));
                }
            });
            var primaryKeys = this._models[model].settings.primaryKeys || [];
            primaryKeys = primaryKeys.slice(0);
            if (primaryKeys.length) {
                for (var i = 0, length = primaryKeys.length; i < length; i++) {
                    primaryKeys[i] = "`" + primaryKeys[i] + "`";
                }
                sql.push("PRIMARY KEY (" + primaryKeys.join(', ') + ")");
            }
            else {
                sql.push('`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL');
            }
            return sql.join(',\n  ');
        };
        FlexiliteDB.prototype.propertySettingsSQL = function (model, prop) {
            var p = this._models[model].properties[prop];
            return this.datatype(p) + ' ' +
                (p.allowNull === false || p['null'] === false ? 'NOT NULL' : 'NULL');
        };
        FlexiliteDB.datatype = function (p) {
            switch ((p.type.name || 'string').toLowerCase()) {
                case 'string':
                case 'varchar':
                    return 'VARCHAR(' + (p.limit || 255) + ')';
                case 'int':
                case 'integer':
                case 'number':
                    return 'INTEGER(' + (p.limit || 11) + ')';
                case 'real':
                case 'float':
                case 'double':
                    return 'REAL';
                case 'date':
                case 'timestamp':
                    return 'DATETIME';
                case 'boolean':
                case 'bool':
                    return 'BOOL';
                default:
                    return 'TEXT';
            }
        };
        FlexiliteDB.prototype.buildWhere = function (conds, adapter, model) {
            var cs = [], or = [], self = adapter, props = self._models[model].properties;
            Object.keys(conds).forEach(function (key) {
                if (key !== 'or') {
                    cs = this.parseCond(cs, key, props, conds, self);
                }
                else {
                    conds[key].forEach(function (oconds) {
                        Object.keys(oconds).forEach(function (okey) {
                            or = this.parseCond(or, okey, props, oconds, self);
                        });
                    });
                }
            });
            if (cs.length === 0 && or.length === 0) {
                return '';
            }
            var orop = "";
            if (or.length) {
                orop = ' (' + or.join(' OR ') + ') ';
            }
            orop += (orop !== "" && cs.length > 0) ? ' AND ' : '';
            return 'WHERE ' + orop + cs.join(' AND ');
        };
        FlexiliteDB.prototype.parseCond = function (cs, key, props, conds, self) {
            var keyEscaped = '`' + key.replace(/\./g, '`.`') + '`';
            var val = self.toDatabase(props[key], conds[key]);
            if (conds[key] === null) {
                cs.push(keyEscaped + ' IS NULL');
            }
            else if (conds[key].constructor.name === 'Object') {
                Object.keys(conds[key]).forEach(function (condType) {
                    val = self.toDatabase(props[key], conds[key][condType]);
                    var sqlCond = keyEscaped;
                    if ((condType === 'inq' || condType === 'nin') && val.length === 0) {
                        cs.push(condType === 'inq' ? 0 : 1);
                        return true;
                    }
                    switch (condType) {
                        case 'gt':
                            sqlCond += ' > ';
                            break;
                        case 'gte':
                            sqlCond += ' >= ';
                            break;
                        case 'lt':
                            sqlCond += ' < ';
                            break;
                        case 'lte':
                            sqlCond += ' <= ';
                            break;
                        case 'between':
                            sqlCond += ' BETWEEN ';
                            break;
                        case 'inq':
                        case 'in':
                            sqlCond += ' IN ';
                            break;
                        case 'nin':
                            sqlCond += ' NOT IN ';
                            break;
                        case 'neq':
                        case 'ne':
                            sqlCond += ' != ';
                            break;
                        case 'regex':
                            sqlCond += ' REGEXP ';
                            break;
                        case 'like':
                            val = (val || '').replace(new RegExp('%25', 'gi'), '%');
                            sqlCond += ' LIKE ';
                            break;
                        case 'nlike':
                            val = (val || '').replace(new RegExp('%25', 'gi'), '%');
                            sqlCond += ' NOT LIKE ';
                            break;
                        default:
                            sqlCond += ' ' + condType + ' ';
                            break;
                    }
                    sqlCond += (condType === 'in' || condType === 'inq' || condType === 'nin') ? '(' + val + ')' : val;
                    cs.push(sqlCond);
                });
            }
            else if (/^\//gi.test(conds[key])) {
                var reg = val.toString().split('/');
                cs.push(keyEscaped + ' REGEXP "' + reg[1] + '"');
            }
            else {
                cs.push(keyEscaped + ' = ' + val);
            }
            return cs;
        };
        FlexiliteDB.prototype.buildOrderBy = function (order) {
            if (typeof order === 'string')
                order = [order];
            return 'ORDER BY ' + order.join(', ');
        };
        FlexiliteDB.prototype.buildLimit = function (limit, offset) {
            return 'LIMIT ' + (offset ? (offset + ', ' + limit) : limit);
        };
        FlexiliteDB.prototype.buildGroupBy = function (group) {
            if (typeof group === 'string') {
                group = [group];
            }
            return 'GROUP BY ' + group.join(', ');
        };
        return FlexiliteDB;
    })(jugglingdb.BaseSQL);
    Flexilite.FlexiliteDB = FlexiliteDB;
})(Flexilite || (Flexilite = {}));
// TODO-- remove require('util').inherits(Flexilite.FlexiliteDB, jugglingdb.BaseSQL);
// TODO -- module.exports = FlexiliteDB;
//# sourceMappingURL=FlexiliteDBAdapter.js.map