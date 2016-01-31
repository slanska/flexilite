/**
 * Created by slanska on 2016-01-18.
 */
/// <reference path="../../../typings/tsd.d.ts"/>
var Driver = require('./Driver');
var orm = require("orm");
// Register Flexilite driver
orm.addAdapter('flexilite', Driver);
//# sourceMappingURL=index.js.map