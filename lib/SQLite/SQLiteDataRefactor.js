/**
 * Created by slanska on 2016-01-16.
 */
// FIXME: rename to SQLiteDataRefactor
var SQLiteDataRefactor = (function () {
    function SQLiteDataRefactor() {
    }
    // Extract object
    /*
     Parameters:
     filter: ObjectFilter
     class: ID | ClassDef
     propertyMapping: [{propID, jsonPath, propName}]


     Create new class (if needed)
     Create schema for new class (if needed)
     Generate views - JSONIC and COLUMNIC
     Insert new object into JSONIC view with path (or extracted content?)
     -- Update old objects by removing content?
     */
    SQLiteDataRefactor.prototype.extractObject = function (filter, mappings) {
    };
    // Map object
    /*
     Same as extract but new object is stored as reference (JsonPath).
     If object is already mapped, JsonPath is concatenated
     */
    SQLiteDataRefactor.prototype.mapObject = function (filter, mappings) {
    };
    // Add property
    /*
     Update schema. Trigger will create new record with old data.
     Set Class.CurrentSchemaID = new.SchemaID
     */
    SQLiteDataRefactor.prototype.addProperty = function (schema, propertyId, propDef) {
    };
    // Insert object
    /*
     In view trigger, ref properties are processed individually (hard coded, based on schema definition)
     Insert child objects, with JsonPath
     Insert into ref-values
     */
    SQLiteDataRefactor.prototype.insertObject = function (classIdOrName, data) {
        return 0; // FIXME
    };
    // Update object
    /*
     new JSON is merged from old JSON and new property values
     find child objects (by HostID), update with new JSON subset (based on object's JsonPath)
     if old.Data <> new.Data (to apply validation).
     Recursively called in trigger
     */
    SQLiteDataRefactor.prototype.updateObject = function (objectId, data, oldData) {
    };
    // Delete object
    /*
     Update child objects, left after removing all ref-values, matching by Host and
     JsonPath. Set extracted JSON from old.Data, based on their JsonPath
     */
    SQLiteDataRefactor.prototype.deleteObject = function (objectId) {
    };
    // Delete property
    SQLiteDataRefactor.prototype.deleteProperty = function (schema, propertyId) {
    };
    // Rename property
    SQLiteDataRefactor.prototype.renameProperty = function (schema, propertyId, newPropertyName) {
    };
    /*
     Updates property(ies) definition.
     Actions:
     - saves new schema in the database
     - updates class.CurrentSchemaID
     - generates views for the class
     */
    SQLiteDataRefactor.prototype.updateProperty = function (schema, propertyId, propDef) {
    };
    // Property: scalar -> collection
    // Split property into multiple: use SQL expressions
    SQLiteDataRefactor.prototype.splitProperty = function () {
    };
    // Merge many properties into one: use SQL expressions
    SQLiteDataRefactor.prototype.mergeProperties = function () {
    };
    // Inject one object into another
    SQLiteDataRefactor.prototype.injectObjects = function () {
    };
    // Move properties from one object to another (partial extract)
    SQLiteDataRefactor.prototype.moveProperties = function () {
    };
    // Create class
    SQLiteDataRefactor.prototype.createClass = function () {
    };
    // Delete class
    SQLiteDataRefactor.prototype.deleteClass = function () {
    };
    // Rename class
    SQLiteDataRefactor.prototype.renameClass = function () {
    };
    // Extend object with other class (mixin)
    SQLiteDataRefactor.prototype.extendObject = function (filter, classIdOrName) {
    };
    return SQLiteDataRefactor;
})();
exports.SQLiteDataRefactor = SQLiteDataRefactor;
//# sourceMappingURL=SQLiteDataRefactor.js.map