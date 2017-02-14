/**
 * Created by slanska on 2017-02-13.
 */

/// <reference path="../typings/lib.d.ts" />
///<reference path="typings/api.d.ts"/>
///<reference path="typings/definitions.d.ts"/>

'use strict';

import sqlite = require('sqlite3');
import _ = require('lodash');
import Promise = require('bluebird');

sqlite.Database.prototype['allAsync'] = Promise.promisify(sqlite.Database.prototype.all) as any;
sqlite.Database.prototype['execAsync'] = Promise.promisify(sqlite.Database.prototype.exec) as any;
sqlite.Database.prototype['runAsync'] = Promise.promisify(sqlite.Database.prototype.run)as any;
sqlite.Database.prototype['loadExtensionAsync'] = Promise.promisify(sqlite.Database.prototype.loadExtension)as any;
sqlite.Database.prototype['closeAsync'] = Promise.promisify(sqlite.Database.prototype.close)as any;

export = sqlite;
