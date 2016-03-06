/**
 * Created by slanska on 2015-11-16.
 */
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports"], factory);
    }
})(function (require, exports) {
    "use strict";
    /// <reference path="../../typings/tsd.d.ts"/>
    var Flexilite;
    (function (Flexilite) {
        var models;
        (function (models) {
            /*
        
             */
            var ClassDef = (function () {
                function ClassDef() {
                }
                return ClassDef;
            }());
            models.ClassDef = ClassDef;
        })(models = Flexilite.models || (Flexilite.models = {}));
    })(Flexilite = exports.Flexilite || (exports.Flexilite = {}));
});
//# sourceMappingURL=ClassDef.js.map