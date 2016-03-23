///<reference path="typings/tsd.d.ts"/>
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports"], factory);
    }
})(function (require, exports) {
    "use strict";
    var syncho = require('syncho');
    var Common = (function () {
        function Common() {
        }
        Common.initMemoryDatabase = function () {
        };
        return Common;
    }());
    return Common;
});
//# sourceMappingURL=common.js.map