/**
 * Created by slanska on 2015-11-17.
 */
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports", './ClassDef'], factory);
    }
})(function (require, exports) {
    "use strict";
    var ClassDef = require('./ClassDef');
    Object.defineProperty(exports, "__esModule", { value: true });
    exports.default = ClassDef.Flexilite.models;
});
//# sourceMappingURL=index.js.map