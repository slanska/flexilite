/**
 * Created by slanska on 2017-10-22.
 */

/*
This script is to provide JS specific API for database related c++
classes (Database, Statement...) which are not fully supported
by Dukglue/C++.
Examples:
1) Multiple constructors - Dukglue allows only one
2) Returning 2 dimension arrays
3) Variadic list of parameters

This script is intended to be executed by DukContext
after c++ classes are registered and before main Flexilite JS bundle is loaded

 */
(function () {
    // Statement
    var savedStatementCtor = Statement.prototype.constructor;
    Statement.prototype.constructor = function () {
        // Check what arguments were passed to the ctor

        return savedStatementCtor(arguments);
    };

    // Returns all rows as array of objects
    Statement.prototype.all = function () {
    };

    // Returns first row as object
    Statement.prototype.get = function () {
    };

    // Binds parameter values
    Statement.prototype.bind = function () {
        this.bindValues(arguments);
    };

    // Database
    // Database.prototype.

})();

var DBContexts = {};

/*
Creates new DBContext and registers it in the pool
@param db : Database
@param dbHandle : sqlite3* casted to uint64_t
 */
function CreateDBContext(db, dbHandle) {
    var dbx = DBContexts[dbHandle];
    if (dbx)
        throw new Error("DBContext for handle " + dbHandle.toString() + " already exists");

    dbx = new DBContext(db, dbHandle);
    DBContexts[dbHandle] = dbx;
    return dbx;
}