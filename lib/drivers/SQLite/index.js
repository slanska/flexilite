/**
 * Created by slanska on 2016-01-18.
 */
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports", './Driver', "orm"], factory);
    }
})(function (require, exports) {
    /// <reference path="../../../typings/tsd.d.ts"/>
    var Driver = require('./Driver');
    var orm = require("orm");
    // Register Flexilite driver
    orm.addAdapter('flexilite', Driver);
});
//# sourceMappingURL=index.js.map