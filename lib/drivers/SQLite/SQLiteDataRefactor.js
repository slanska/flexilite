/**
 * Created by slanska on 2016-01-16.
 */
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports", 'sqlite3', '../../misc/SchemaHelper', '../../misc/reverseEng', 'lodash'], factory);
    }
})(function (require, exports) {
    "use strict";
    ///<reference path="../../../typings/lib.d.ts"/>
    ///<reference path="DBInterfaces.d.ts"/>
    var sqlite3 = require('sqlite3');
    var SchemaHelper_1 = require('../../misc/SchemaHelper');
    var Sync = require('syncho');
    var reverseEng_1 = require('../../misc/reverseEng');
    var _ = require('lodash');
    var SQLiteDataRefactor = (function () {
        function SQLiteDataRefactor(DB) {
            this.DB = DB;
            this._lastActionReport = '';
        }
        /*
    
         */
        SQLiteDataRefactor.prototype.importFromDatabase = function (options) {
            var self = this;
            var srcDB = self.DB;
            var srcTbl = options.sourceTable || options.targetTable;
            if (options.sourceConnectionString) {
                srcDB = new sqlite3.Database(options.sourceConnectionString, sqlite3.OPEN_READONLY);
                if (_.isEmpty(srcTbl))
                    srcTbl = options.targetTable;
            }
            else {
                if (srcTbl === options.targetTable)
                    throw new Error("Source and target tables cannot be the same");
            }
            // load metadata for source table
            var reng = new reverseEng_1.ReverseEngine(srcDB);
            var srcMeta = reng.loadSchemaFromDatabase();
            var srcTableMeta = srcMeta[srcTbl];
            // Check if target flexitable exists
            var clsDef = self.getClassDefByName(options.targetTable);
            if (!clsDef) {
                var schemaHlp = new SchemaHelper_1.SchemaHelper(self.DB, srcTableMeta, options.columnNameMap);
                schemaHlp.getNameID = self.getNameID.bind(self);
                schemaHlp.getClassIDbyName = self.getClassIDbyName.bind(self);
                schemaHlp.convertFromNodeOrmSync();
                clsDef = {};
                clsDef.NameID = self.getNameByValue(options.targetTable).NameID;
                clsDef.Data = { properties: schemaHlp.targetClassProps };
                self.createClass(options.targetTable, clsDef.Data);
            }
            var batchCnt = 0;
            var selQry = "select * from [" + srcTbl + "]";
            if (!_.isEmpty(options.whereClause))
                selQry += " where " + options.whereClause;
            selQry += ";";
            var insSQL = '';
            var insSQLValues = '';
            var insStmt = null;
            try {
                var runner = function (callback) {
                    self.DB.serialize(function () {
                        srcDB.each(selQry, function (error, row) {
                            //console.log(row);
                        }, function (err, count) {
                            console.log(count);
                            callback(err, count);
                        });
                    });
                };
                var rowHandler = function (callback) {
                    srcDB.each(selQry, function (error, row) {
                        try {
                            if (error) {
                                if (batchCnt !== 0)
                                    srcDB.exec.sync(srcDB, "rollback to savepoint aaa;");
                                callback(error);
                            }
                            batchCnt++;
                            if (batchCnt === 1) {
                                srcDB.exec.sync(srcDB, "savepoint aaa;");
                            }
                            var newObj = {};
                            if (!insStmt) {
                                insSQL = "insert into [" + options.targetTable + "] (";
                                insSQLValues = ") values (";
                            }
                            var fldNo_1 = 0;
                            _.each(row, function (fld, fldName) {
                                if (options.columnNameMap) {
                                    fldName = options.columnNameMap[fldName];
                                    if (_.isEmpty(fldName))
                                        return;
                                }
                                var paramName = "" + ++fldNo_1;
                                newObj[paramName] = fld;
                                if (!insStmt) {
                                    if (fldNo_1 > 1) {
                                        insSQLValues += ', ';
                                        insSQL += ",";
                                    }
                                    insSQLValues += paramName;
                                    insSQL += "[" + fldName + "]";
                                }
                            });
                            if (!insStmt) {
                                insSQL += insSQLValues + ');';
                                insStmt = self.DB.prepare(insSQL);
                            }
                            insStmt.run.sync(insStmt, newObj);
                            if (batchCnt >= 10000) {
                                srcDB.exec.sync(srcDB, "release aaa;");
                                batchCnt = 0;
                            }
                        }
                        catch (err) {
                            console.error(err);
                        }
                    }, function (error, rowCount) {
                        if (batchCnt > 0) {
                            srcDB.exec.sync(srcDB, "release aaa;");
                        }
                    });
                };
                var rslt = runner.sync(self);
                console.log("Done");
            }
            catch (err) {
                if (batchCnt !== 0)
                    srcDB.exec.sync(srcDB, "rollback to savepoint aaa;");
                throw err;
            }
            finally {
                console.log("Done");
            }
        };
        /*
         Loads class properties from rows, assuming that rows are loaded from .classes table
         */
        SQLiteDataRefactor.prototype.getClassDefFromRows = function (rows) {
            var self = this;
            if (rows.length > 0) {
                rows[0].Data = JSON.parse(rows[0].Data);
                var result = rows[0];
                result.Properties = self.DB.all.sync(self.DB, "select * from [.class_properties] where ClassID = $classID", { $classID: result.ClassID });
                return result;
            }
            return null;
        };
        /*
    
         */
        SQLiteDataRefactor.prototype.getClassDefByName = function (className) {
            var self = this;
            var rows = self.DB.all.sync(self.DB, "select * from [.classes] where NameID = (select NameID from [.names] where [Value]= $name) limit 1", { $name: className });
            return self.getClassDefFromRows(rows);
        };
        /*
    
         */
        SQLiteDataRefactor.prototype.getClassIDbyName = function (className) {
            var cls = this.getClassDefByName(className);
            return cls.ClassID;
        };
        /*
    
         */
        SQLiteDataRefactor.prototype.getClassDefByID = function (classID) {
            var self = this;
            var rows = self.DB.all.sync(self.DB, "select * from [.classes] where ClassID = $ClassID limit 1", { $ClassID: classID });
            return self.getClassDefFromRows(rows);
        };
        /*
    
         */
        SQLiteDataRefactor.prototype.getNameByValue = function (name) {
            this.DB.run.sync(this.DB, "insert or ignore into [.names] ([Value]) values ($name);", { $name: name });
            var rows = this.DB.all.sync(this.DB, "select * from [.names] where [Value] = $name limit 1;", { $name: name });
            return rows[0];
        };
        /*
    
         */
        SQLiteDataRefactor.prototype.getNameByID = function (id) {
            var rows = this.DB.run.sync(this.DB, "select * from [.names] where [NameID] = id limit 1", { $id: id });
            if (rows.length > 0)
                return rows[0];
            return null;
        };
        /*
    
         */
        SQLiteDataRefactor.prototype.getNameID = function (name) {
            var nm = this.getNameByValue(name);
            return nm.NameID;
        };
        SQLiteDataRefactor.prototype.getLastActionReport = function () {
            return this._lastActionReport;
        };
        /*
         Alter class definition.
         @newClassDef - can add/remove or change properties
         Note: property renaming is not supported here. alterClassProperty should be used for that.
    
         */
        SQLiteDataRefactor.prototype.alterClass = function (classID, newClassDef, newName) {
            var self = this;
            var classChanged = false;
            // Check if class exists
            var classDef = self.getClassDefByID(classID);
            if (classDef) {
                if (newClassDef) {
                    classChanged = true;
                }
                if (!_.isEmpty(newName)) {
                    classDef.Name = newName;
                    classChanged = true;
                }
                if (classChanged) {
                    self.DB.serialize.sync(self.DB, function () {
                        var newNameId = self.getNameByValue(classDef.Name).NameID;
                        self.DB.run("update [.classes] set NameID = $NameID where ClassID=$ClassID;", { $NameID: newNameId, ClassID: classID });
                    });
                }
            }
            else
                throw new Error("Flexilite.alterClass: class with ID '" + classID + "' not found");
        };
        /*
    
         */
        SQLiteDataRefactor.prototype.applyClassDefinition = function (classDef) {
            var self = this;
            // TODO
        };
        // TODO validateClassName
        /*
         Create new Flexilite class using @name and @classDef as class definition
         */
        SQLiteDataRefactor.prototype.createClass = function (name, classDef) {
            var self = this;
            var clsDef = self.getClassDefByName(name);
            if (clsDef) {
                self.alterClass(clsDef.ClassID, classDef);
            }
            else {
                var jsonClsDef = JSON.stringify(classDef);
                self.DB.exec.sync(self.DB, "create virtual table [" + name + "] using 'flexi_eav' ('" + jsonClsDef + "');");
            }
        };
        /*
         Drops class and all its data
         */
        SQLiteDataRefactor.prototype.dropClass = function (classID) {
            var self = this;
            var clsDef = self.getClassDefByID(classID);
            self.DB.exec.sync(self.DB, "drop table [" + clsDef.Name + "]");
        };
        SQLiteDataRefactor.prototype.propertiesToObject = function (filter, propIDs, newRefProp, targetClassID, sourceKeyPropID, targetKeyPropID) {
        };
        SQLiteDataRefactor.prototype.objectToProperties = function (classID, refPropID, filter, propMap) {
        };
        SQLiteDataRefactor.prototype.structuralMerge = function (sourceClassID, sourceFilter, sourceKeyPropID, targetClassID, targetKeyPropID, propMap) {
        };
        SQLiteDataRefactor.prototype.structuralSplit = function (sourceClassID, filter, targetClassID, propMap, targetClassDef) {
        };
        SQLiteDataRefactor.prototype.moveToAnotherClass = function (sourceClassID, filter, targetClassID, propMap) {
        };
        SQLiteDataRefactor.prototype.removeDuplicatedObjects = function (classID, filter, compareFunction, keyProps, replaceTargetNulls) {
        };
        SQLiteDataRefactor.prototype.splitProperty = function (classID, sourcePropID, propRules) {
        };
        SQLiteDataRefactor.prototype.mergeProperties = function (classID, sourcePropIDs, targetProp, expression) {
        };
        SQLiteDataRefactor.prototype.alterClassProperty = function (classID, propertyName, propDef, newPropName) {
        };
        SQLiteDataRefactor.prototype.createClassProperty = function (classID, propertyName, propDef) {
        };
        SQLiteDataRefactor.prototype.dropClassProperty = function (classID, propertyName) {
        };
        /*
         Synchronizes node-orm model to .classes and .class_properties.
         Makes updates to the database.
         Returns instance of ICollectionDef, with all changes applied
         NOTE: this function is intended to run inside Syncho wrapper
         */
        /*
         Links in wiki:
         hasMany https://github.com/dresende/node-orm2/wiki/hasMany
    
         hasOne: https://github.com/dresende/node-orm2/wiki/hasOne
         extendsTo: https://github.com/dresende/node-orm2/wiki/extendsTo
    
         hasMany and hasOne are converted into reference properties
         */
        // TODO Callback, Sync version
        SQLiteDataRefactor.prototype.generateClassDefForSync = function (model) {
            var self = this;
            // TODO SQLite checkpoint
            var vars = {};
            vars.DB = self.DB;
            // Get mapping schema and class properties.
            // They come as Dictionary of IClassProperty by property name and
            // Dictionary of schema property def by property name
            // Need to transform them before saving to dictionaries by property ID
            vars.converter = new SchemaHelper_1.SchemaHelper(self.DB, model);
            vars.converter.getNameID = self.getNameByID.bind(self);
            vars.converter.getClassIDbyName = function (name) {
                return self.getClassDefByName(name).ClassID;
            };
            vars.converter.convertFromNodeOrmSync();
            /*
             0.1 Init variables: existing properties, properties to delete
             1. Find class
             1.1 exists? get existing properties and properties to delete
             1.2 no? create new class, save in database to get class ID. BaseSchemaID is not set yet
             2.1 Get name IDs for new properties
             2.2 Prepare list of existing column assignments: dictionary by column name (A..J) to property Name ID. Also include
             priority level: 100 for ID role, 90 - Code, 80 - unique index, 70 - index, 60 - scalar required,
             50 - scalar not required, 0 - others
             2.3 for every prop check if it needs/wishes to have fixed column assigned. Rule is:
             if there is existing property with column assigned, keep it unless there are new properties with higher
             priority level
    
             4. Check if there are some properties which switch from BOXED_OBJECT to FKEY ->
             process them by creating new objects, copy property values, delete properties from existing records
             5. Delete obsolete properties
             6. Insert or replace new/existing properties
             7. Update class: BaseSchemaID, ViewOutdated, Data, Hash
             8. Generate view with triggers
             */
            // Initialize
            vars.existingProps = {}; // Dictionary by property name
            vars.propsToDelete = []; // Array of properties
            vars.newProps = {}; // Dictionary by property name
            vars.columnAssignments = {};
            // Init items for [.class_properties]
            _.forEach(vars.converter.targetClassProps, function (p, n) {
                var nameID = self.getNameByValue(n).NameID;
                var np = {};
                np.NameID = nameID;
                np.ctlv = 0; // TODO to set later
                np.Data = p;
                vars.newProps[n] = np;
            });
            // Load existing class definition if exists
            var classNameID = self.getNameByValue(model.table).NameID;
            vars.classDef = self.getClassDefByName(model.table);
            if (vars.classDef) 
            // Class already exists. It would be ALTER CLASS rather than CREATE CLASS
            {
                self.initWhenClassExists(self, vars);
            }
            else 
            // Class does not exist. Insert new one to get ClassID
            {
                SQLiteDataRefactor.saveNewClass(self, vars, model);
            }
            this.initExistingColAssignment(vars);
            self.initAndSaveProperties(self, vars);
            // Now vars.newProps are saved and have property IDs assigned
            // Set column assignments
            this.assignColumns(self, vars, 2 /* COL_ASSIGN_REQUIRED */);
            this.assignColumns(self, vars, 1 /* COL_ASSIGN_DESIRED */);
            // Set class properties
            // ctloMask
            vars.classDef.ctloMask = 0 /* CTLO_NONE */;
            // Column assignments
            for (var idx = 0; idx < SQLiteDataRefactor.COLUMN_LETTERS.length; idx++) {
                var ch = SQLiteDataRefactor.COLUMN_LETTERS[idx];
                var propID = vars.columnAssignments[ch].propID;
                vars.classDef[ch] = propID;
                if (propID) {
                    var ch_offset = ch.charCodeAt(0) - 'A'.charCodeAt(0);
                    var p = vars.newProps[propID];
                    if (p.Data.unique || (p.Data.role & 8 /* PROP_ROLE_CODE */) || (p.Data.role & 4 /* PROP_ROLE_ID */)) {
                        vars.classDef.ctloMask |= 1 << (1 + ch_offset);
                    }
                    else if (p.Data.indexed) {
                        vars.classDef.ctloMask |= 1 << (13 + ch_offset);
                    }
                    else if (p.Data.fastTextSearch) {
                        vars.classDef.ctloMask |= 1 << (25 + ch_offset);
                    }
                }
            }
            // Check if there are properties that have changed from OBJECT to LINK
            // TODO
            self.applyClassDefinition(vars.classDef);
        };
        /*
    
         */
        SQLiteDataRefactor.prototype.assignColumns = function (self, vars, target_priority) {
            _.forEach(vars.newProps, function (p, id) {
                var prop_priority = self.determineColAssignmentPriority(p.Data);
                if (prop_priority === target_priority) {
                    // Find unused columns first
                    var ca = _.find(vars.columnAssignments, function (ca) {
                        return ca.priority === 0 /* COL_ASSIGN_NOT_SET */;
                    });
                    if (ca) {
                        ca.propID = id;
                        return;
                    }
                    // Find already assigned columns, but associated with lower-priority properties
                    ca = _.find(vars.columnAssignments, function (ca) {
                        return ca.priority < target_priority;
                    });
                    if (ca) {
                        ca.propID = id;
                        return;
                    }
                }
            });
        };
        /*
    
         */
        SQLiteDataRefactor.prototype.initExistingColAssignment = function (vars) {
            // Set column assignment
            for (var c = 0; c < SQLiteDataRefactor.COLUMN_LETTERS.length; c++) {
                var pid = vars.classDef[SQLiteDataRefactor.COLUMN_LETTERS[c]];
                var prior = 0 /* COL_ASSIGN_NOT_SET */;
                if (pid) {
                    prior = this.determineColAssignmentPriority(vars.classDef.Data.properties[pid]);
                }
                vars.columnAssignments[c] = { propID: pid, priority: prior };
            }
        };
        /*
    
         */
        SQLiteDataRefactor.prototype.determineColAssignmentPriority = function (cp) {
            var prior = 0 /* COL_ASSIGN_NOT_SET */;
            if ((cp.role & 4 /* PROP_ROLE_ID */) || (cp.role & 8 /* PROP_ROLE_CODE */) || cp.unique || cp.indexed)
                prior = 2 /* COL_ASSIGN_REQUIRED */;
            else {
                switch (cp.rules.type) {
                    case 7 /* PROP_TYPE_BINARY */:
                    case 11 /* PROP_TYPE_JSON */:
                    case 12 /* PROP_TYPE_LINK */:
                    case 5 /* PROP_TYPE_OBJECT */:
                        prior = 0 /* COL_ASSIGN_NOT_SET */;
                        break;
                    default:
                        prior = 1 /* COL_ASSIGN_DESIRED */;
                }
            }
            return prior;
        };
        SQLiteDataRefactor.prototype.initAndSaveProperties = function (self, vars) {
            // Fill updated properties
            var updPropStmt = self.DB.prepare("insert or replace into [.class_properties] \n                (PropertyID, ClassID, NameID, ctlv) \n                values ($PropertyID, $ClassID, $NameID, $ctlv);");
            // Initialize properties
            _.forEach(vars.converter.targetClassProps, function (p, propName) {
                var np = {};
                np.ClassID = vars.classDef.ClassID;
                np.NameID = self.getNameByValue(propName).NameID;
                np.ctlv = 0;
                if (p.unique) {
                    np.ctlv |= 128 /* UNIQUE_INDEX */;
                }
                else if (p.indexed) {
                    np.ctlv |= 1 /* INDEX */;
                }
                if (p.fastTextSearch) {
                    np.ctlv |= 16 /* FULL_TEXT_INDEX */;
                }
                vars.newProps[propName] = np;
                updPropStmt.run.sync(updPropStmt, {
                    $PropertyID: np.PropertyID,
                    $ClassID: np.ClassID,
                    $NameID: np.NameID,
                    $ctlv: np.ctlv
                });
            });
        };
        /*
    
         */
        SQLiteDataRefactor.saveNewClass = function (self, vars, model) {
            vars.classDef = {};
            vars.classDef.NameID = self.getNameByValue(model.table).NameID;
            vars.classDef.ctloMask = 0; // TODO
            var clsID = self.DB.all.sync(self.DB, "insert or replace into [.classes] (NameID, BaseSchemaID, ctloMask, A, B, C, D, E, F, G, H, I, J) \n                values ($NameID, $ctloMask, $A, $B, $C, $D, $E, $F, $G, $H, $I, $J); select last_insert_rowid();", {
                $NameID: vars.classDef.NameID,
                $ctloMask: vars.classDef.ctloMask,
                $A: vars.classDef.A,
                $B: vars.classDef.B,
                $C: vars.classDef.C,
                $D: vars.classDef.D,
                $E: vars.classDef.E,
                $F: vars.classDef.F,
                $G: vars.classDef.G,
                $H: vars.classDef.H,
                $I: vars.classDef.I,
                $J: vars.classDef.J,
                $Hash: vars.classDef.Hash,
                $Data: JSON.stringify(vars.classDef.Data)
            });
            vars.classDef.ClassID = clsID;
        };
        /*
         Initializes vars with data from existing class
         */
        SQLiteDataRefactor.prototype.initWhenClassExists = function (self, vars) {
            // Load .class_properties
            var classProps = self.DB.all.sync(self.DB, "select * from [.vw_class_properties] where ClassID = $ClassID;", { $ClassID: vars.classDef.ClassID });
            // Add property to either existing list or to candidates for removal
            _.forEach(classProps, function (p) {
                if (vars.converter.targetClassProps[p.Name])
                    vars.existingProps[p.PropertyID] = p;
                else
                    vars.propsToDelete.push(p);
            });
            // Set IDs for existing properties
            _.forEach(vars.newProps, function (np, id) {
                var ep = vars.existingProps[np.NameID];
                if (ep) {
                    np.PropertyID = ep.PropertyID;
                }
            });
            var delPropStmt = self.DB.prepare("delete from [.class_properties] where PropertyID = $propID");
            // Remove properties that are not in the new structure
            _.forEach(vars.propsToDelete, function (p, idx) {
                delPropStmt.run.sync(delPropStmt, { $propID: p.PropertyID });
            });
        };
        SQLiteDataRefactor.COLUMN_LETTERS = 'ABCDEFGHIJ'; // TODO KLMNOP
        return SQLiteDataRefactor;
    }());
    exports.SQLiteDataRefactor = SQLiteDataRefactor;
});
//# sourceMappingURL=SQLiteDataRefactor.js.map