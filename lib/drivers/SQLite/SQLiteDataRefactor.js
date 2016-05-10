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
    // var Sync = require('syncho');
    var reverseEng_1 = require('../../misc/reverseEng');
    var _ = require('lodash');
    var SQLiteDataRefactor = (function () {
        function SQLiteDataRefactor(DB) {
            this.DB = DB;
            this._lastActionReport = [];
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
            var nProcessed = 0;
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
                        var inTrn = false;
                        srcDB.each(selQry, function (error, row) {
                            if (error) {
                                if (inTrn) {
                                    srcDB.exec("rollback to savepoint aaa;");
                                    inTrn = false;
                                }
                                callback(error, nProcessed);
                            }
                            nProcessed++;
                            if (!inTrn) {
                                srcDB.exec("savepoint aaa;");
                                inTrn = true;
                            }
                            var newObj = {};
                            if (!insStmt) {
                                insSQL = "insert into [" + options.targetTable + "] (";
                                insSQLValues = ") values (";
                            }
                            var fldNo = 0;
                            _.each(row, function (fld, fldName) {
                                if (options.columnNameMap) {
                                    fldName = options.columnNameMap[fldName];
                                    if (_.isEmpty(fldName))
                                        return;
                                }
                                var paramName = "$" + ++fldNo;
                                newObj[paramName] = fld;
                                if (!insStmt) {
                                    if (fldNo > 1) {
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
                            insStmt.run(newObj);
                            if (nProcessed % 10000 === 0 && inTrn) {
                                srcDB.exec("release aaa;");
                                inTrn = false;
                            }
                        }, function (err, count) {
                            insStmt.finalize();
                            if (inTrn) {
                                if (err)
                                    srcDB.exec("rollback to savepoint aaa;");
                                else
                                    srcDB.exec("release aaa;");
                            }
                            callback(err, count);
                        });
                    });
                };
                var rslt = runner.sync(self);
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
        SQLiteDataRefactor.prototype.alterClass = function (className, newClassDef, newName) {
            var self = this;
            var classChanged = false;
            // Check if class exists
            var classDef = self.getClassDefByName(className);
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
                        self.DB.run("update [.classes] set NameID = $NameID where ClassID=$ClassID;", { $NameID: newNameId, ClassID: classDef.ClassID });
                    });
                }
            }
            else
                throw new Error("Flexilite.alterClass: class '" + className + "' not found");
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
                self.alterClass(name, classDef);
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
        /*
    
         */
        SQLiteDataRefactor.prototype.removeDuplicatedObjects = function (classID, filter, compareFunction, keyProps, replaceTargetNulls) {
        };
        SQLiteDataRefactor.prototype.splitProperty = function (classID, sourcePropID, propRules) {
        };
        SQLiteDataRefactor.prototype.mergeProperties = function (classID, sourcePropIDs, targetProp, expression) {
        };
        /*
         Returns class property definition by property ID
         */
        SQLiteDataRefactor.prototype.getClassPropertyByID = function (propID) {
            var self = this;
            var rows = self.DB.all.sync(self.DB, "select * from [.class_properties] where PropertyID = $PropertyID limit 1;", { $PropertyID: propID });
            return rows.length === 1 ? rows[0] : null;
        };
        /*
         Returns class property definition by class ID and property name
         */
        SQLiteDataRefactor.prototype.getClassProperty = function (classID, propertyName) {
            var self = this;
            var rows = self.DB.all.sync(self.DB, "select * from [.class_properties] where ClassID = $ClassID \n        and NameID = (select NameID from [.names] where Value = $PropName) limit 1;", { $ClassID: classID, $PropName: propertyName });
            return rows.length === 1 ? rows[0] : null;
        };
        /*
         Applies changes for property that either used to be reference type or switched to be reference type.
         There is also a case when property stays reference but settings have changes (different class, different
         reverse property etc.)
         */
        SQLiteDataRefactor.prototype.doAlterRefProp = function (clsDef, propertyName, curPropDef, propDef) {
            var self = this;
            var newRef = false;
            var curRef = false;
            // Determining scope of changes
            if (propDef.rules.type === 12 /* PROP_TYPE_LINK */ || propDef.rules.type === 5 /* PROP_TYPE_OBJECT */) {
                newRef = true;
            }
            if (curPropDef.rules.type === 12 /* PROP_TYPE_LINK */ || curPropDef.rules.type === 5 /* PROP_TYPE_OBJECT */) {
                curRef = true;
            }
            if (!curRef && !newRef)
                return;
            if (newRef) {
                if (!propDef.reference) {
                    throw new Error("Reference definition is missing in " + clsDef.Name + "." + propertyName);
                }
                var refClsDef = null;
                if (propDef.reference.$className) {
                    refClsDef = self.getClassDefByName(propDef.reference.$className);
                    if (!refClsDef)
                        throw new Error("Referenced class (Name=" + propDef.reference.$className + ") not found");
                    propDef.reference.classID = refClsDef.ClassID;
                    delete propDef.reference.$className;
                }
                else {
                    refClsDef = self.getClassDefByID(propDef.reference.classID);
                    if (!refClsDef)
                        throw new Error("Referenced class (ID=" + propDef.reference.classID + ") not found");
                }
                var revPropDef = null;
                if (propDef.reference.reversePropertyID || propDef.reference.$reversePropertyName) {
                    if (propDef.reference.reversePropertyID)
                        revPropDef = self.getClassPropertyByID(propDef.reference.reversePropertyID);
                    else if (propDef.reference.$reversePropertyName) {
                        revPropDef = self.getClassProperty(propDef.reference.classID, propDef.reference.$reversePropertyName);
                        delete propDef.reference.$reversePropertyName;
                    }
                    if (!revPropDef) 
                    // Not found
                    {
                        var revPropDef_1 = { reference: {}, rules: { type: 12 /* PROP_TYPE_LINK */ } };
                        revPropDef_1.reference.classID = clsDef.ClassID;
                        self.createClassProperty(propDef.reference.classID, propDef.reference.$reversePropertyName, revPropDef_1);
                    }
                    else {
                        var revClsDef = self.getClassDefByID(propDef.reference.classID);
                        revPropDef.Data.rules.type = 12 /* PROP_TYPE_LINK */;
                        self.alterClassProperty(revClsDef.Name, propDef.reference.$reversePropertyName, revPropDef.Data);
                    }
                    propDef.reference.reversePropertyID = self.getNameByValue(propDef.reference.$reversePropertyName).NameID;
                    delete propDef.reference.$reversePropertyName;
                }
                if (!curRef) {
                    // TODO
                    /*
                     if property was not reference property and now is, the following logic will be applied.
                     existing value(s) will be treated as ID, Code, ObjectID (sequentially). If no match is found, property will stay
                     unchanged and class will be marked with CTLO_HAS_INVALID_REFS.
    
                     If property was reference and not is not, ID, Code, ObjectID of referenced object will be used for scalar value of
                     property.
    
                     If property was reference and reference definition has changed (pointing to another class, different
                     reverseProperty) - Flexilite will attempt to switch to another property
                     */
                    if (propDef.reference.reversePropertyID) {
                    }
                    // Load referenced class def
                    var idPropID_1;
                    // Check if it has property with role ID or Code
                    var idProp = _.find(refClsDef.Data.properties, function (pd, pID) {
                        if ((pd.role & 4 /* PROP_ROLE_ID */) != 0) {
                            idPropID_1 = pID;
                            return true;
                        }
                        return false;
                    });
                    if (!idProp) {
                        idProp = _.find(refClsDef.Data.properties, function (pd, pID) {
                            if ((pd.role & 8 /* PROP_ROLE_CODE */) != 0) {
                                idPropID_1 = pID;
                                return true;
                            }
                            return false;
                        });
                    }
                    if (idProp) {
                        var pn = self.getNameByID(Number(idPropID_1));
                        var sql = "update [.ref-values] set [Value] = \n                        (select rowid from [" + refClsDef.Name + "] where [" + pn.Value + "] = [.ref-values].[Value] limit 1),\n                        ctlv = ctlv | $ctlv\n                        where PropertyID = $PropertyID;";
                        self.DB.run.sync(self.DB, sql, { $PropertyID: 0 });
                    }
                    else {
                        var pn = self.getNameByID(Number(idPropID_1));
                        var sql = "update [.ref-values] set [Value] = \n                        (select rowid from [" + refClsDef.Name + "] where rowid = [.ref-values].[Value] limit 1),\n                        ctlv = ctlv | $ctlv\n                        where PropertyID = $PropertyID;";
                        self.DB.run.sync(self.DB, sql, { $PropertyID: 0 });
                    }
                }
                else {
                    if (curPropDef.reference.reversePropertyID &&
                        (curPropDef.reference.reversePropertyID !== propDef.reference.reversePropertyID
                            || curPropDef.reference.classID !== propDef.reference.classID)) {
                        var sql = "delete from [.class_properties] where PropertyID = $PropertyID";
                        self.DB.run(sql, { $PropertyID: curPropDef.reference.reversePropertyID });
                    }
                }
            }
            else if (!curRef) {
            }
        };
        /*
         Internal function for altering individual property. Applies changes directly to clsDef.properties
         but does not start transaction, does not update [.class_properties].
         When applying changes, tries to minimize amount of updates on DB.
         */
        SQLiteDataRefactor.prototype.doAlterClassProperty = function (clsDef, propertyName, propDef, newPropName) {
            var self = this;
            var propRow = _.find(clsDef.Properties, function (prop, idx) {
                return prop.Name === propertyName;
            });
            if (propDef.$renameTo) {
                newPropName = propDef.$renameTo;
                delete propDef.$renameTo;
            }
            if (newPropName) {
                propRow.NameID = self.getNameByValue(newPropName).NameID;
            }
            var curPropDef = clsDef.Data.properties[propRow.PropertyID];
            self.doAlterRefProp(clsDef, propertyName, curPropDef, propDef);
            // If new property definition is reference, assume job is done
            if (propDef.rules.type === 12 /* PROP_TYPE_LINK */ || propDef.rules.type === 5 /* PROP_TYPE_OBJECT */)
                return;
            var newUnique = false;
            var curUnique = false;
            // Check if there are changes in indexing
            if ((propDef.role && (8 /* PROP_ROLE_CODE */ || 4 /* PROP_ROLE_ID */) !== 0) || propDef.unique) {
                newUnique = true;
            }
            if ((curPropDef.role && (8 /* PROP_ROLE_CODE */ || 4 /* PROP_ROLE_ID */) !== 0) || curPropDef.unique) {
                curUnique = true;
            }
            if (newUnique !== curUnique) {
                // TODO
                /*
                 if was unique and now not unique - do nothing. Just change property definition and all new updates
                 and inserts will not have CTLV_UNIQUE_INDEX flag. Also, for search index will not be used and linear
                 search will be performed.
    
                 if was not unique and now unique - need to check for possible duplicates. Only first occurences
                 of every value gets indexed with CTLV_UNIQUE_INDEX flag. Duplicates will
                 get CTLV_DUP_VALUE flag, and class property will have CTLV_DUP_VALUE flag set as well. Only first
                 occurence of every value will be indexed via CTLV_UNIQUE_INDEX (but will still get CTLV_DUP_VALUE flag)
                 Search will be performed using CTLV_UNIQUE_INDEX. When property with CTLV_DUP_VALUE gets changed,
                 all duplicated values are reviewed again for duplicates, and values that now become unique, will be
                 indexed via CTLV_UNIQUE_INDEX. Support for this is done through trigger on [.ref-values]
                 */
                var sql = "select count(*) from [.ref-values] where [PropertyID] = $PropertyID \n                and ObjectID = (select ObjectID from [.objects] where ClassID = $ClassID limit 1) group by Value;";
                var rows = self.DB.all.sync(self.DB, sql, { $PropertyID: propRow.PropertyID, $ClassID: clsDef.ClassID });
            }
            else if (Boolean(propDef.indexed) != Boolean(curPropDef.indexed)) {
            }
            if (propDef.fastTextSearch != curPropDef.fastTextSearch) {
            }
            // TODO if property type changes to range*
            /*
             when new property type is one of PROP_TYPE_RANGE* values and existing property type is not
             range type, the following logic gets applied.
             if new property definition has $lowBoundPropertyName and/or $highBoundPropertyName,
             these properties are used as source for low and high bound values respectively
             if either $lowBoundPropertyName or $highBoundPropertyName is not specified, existing values
             are treated as source values. If neither one is specified, existing properties are expected to be
             in one of the following formats: 'L H' 'L;H' 'L:H' 'L..H' 'L...H' 'L,H' 'L-H'. These formats applied
             one after another, until matching format is found. Note that some formats place limitations on the way what
             values can be stored ('L,H' 'L-H')
             For objects where none of those formats can be applied, flag CTLO_HAS_INVALID_DATA will be set and their
             existing value and type will not change
    
             If property definition has flag CTLV_RANGE_INDEX_* (A to D), those values will automatically indexed in
             [.range-data] table for fast range lookup
             */
            // TODO Validate
            /*
             when any property rules change, Flexilite will scan existing property values and validate values for matching
             to the new rules. If at least one invalid object is found, property definition will
             get flag CTLV_HAS_INVALID_DATA. No updates to existing objects is performed. There is special API to query invalid
             objects and optionally mark them with CTLV_HAS_INVALID_DATA and CTLO_HAS_INVALID_DATA flags.
             */
        };
        /*
         Finds property by name in collection of class properties.
         Returns null if not found
         */
        SQLiteDataRefactor.prototype.findClassPropertyByName = function (clsDef, propName) {
            var self = this;
            var n = self.getNameByValue(propName);
            var result = _.find(clsDef.Data.properties, function (cp, pID) {
                return Number(pID) === n.NameID;
            });
            return result;
        };
        /*
         Alters single class property definition
         */
        SQLiteDataRefactor.prototype.alterClassProperty = function (className, propertyName, propDef, newPropName) {
            var self = this;
            self._lastActionReport = [];
            var clsDef = self.getClassDefByName(className);
            if (!clsDef)
                throw new Error("Class " + className + " not found");
            var cp = self.findClassPropertyByName(clsDef, propertyName);
            if (cp) {
                self.doAlterClassProperty(clsDef, propertyName, propDef, newPropName);
            }
            else {
                self.doCreateClassProperty(clsDef, propertyName, propDef);
            }
        };
        /*
    
         */
        SQLiteDataRefactor.prototype.doCreateClassProperty = function (clsDef, propertyName, propDef) {
        };
        SQLiteDataRefactor.prototype.getInvalidObjects = function (className, markAsInvalid) {
            // TODO
            return null;
        };
        SQLiteDataRefactor.prototype.createClassProperty = function (className, propertyName, propDef) {
            this.alterClassProperty(className, propertyName, propDef);
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
                    np.ctlv |= 128 /* CTLV_UNIQUE_INDEX */;
                }
                else if (p.indexed) {
                    np.ctlv |= 1 /* CTLV_INDEX */;
                }
                if (p.fastTextSearch) {
                    np.ctlv |= 16 /* CTLV_FULL_TEXT_INDEX */;
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