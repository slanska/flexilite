/**
 * Created by slanska on 2016-01-16.
 */
"use strict";
///<reference path="../../../../typings/lib.d.ts"/>
///<reference path="DBInterfaces.d.ts"/>
var sqlite3 = require('sqlite3');
var SchemaHelper_1 = require('../../misc/SchemaHelper');
var reverseEng_1 = require('../../../flexish/reverseEng');
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
        var srcMeta = reng.parseSchema();
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
    SQLiteDataRefactor.prototype.alterClass = function (className, newClassDef, newName, invalidDataBehavior) {
        if (invalidDataBehavior === void 0) { invalidDataBehavior = 0 /* INV_DT_BEH_MARKCLASS */; }
        var self = this;
        var clsDef = self.getClassDefByName(name);
        if (clsDef) {
            self.doAlterClass(name, newClassDef);
        }
        else {
            self.doCreateClass(name, newClassDef);
        }
    };
    /*

     */
    SQLiteDataRefactor.prototype.doCreateClass = function (name, classDef) {
        var self = this;
        var jsonClsDef = JSON.stringify(classDef);
        self.DB.serialize(function () {
            self.DB.exec("create virtual table [" + name + "] using 'flexi_eav' ('" + jsonClsDef + "');");
        });
    };
    /*

     */
    SQLiteDataRefactor.prototype.doAlterClass = function (name, newClassDef, newName) {
        var self = this;
        var classChanged = false;
        // Check if class exists
        var classDef = self.getClassDefByName(name);
        if (classDef) {
            if (classDef) {
                classChanged = true;
            }
            if (!_.isEmpty(newName)) {
                classDef.Name = newName;
                classChanged = true;
            }
            if (classChanged) {
                self.DB.serialize.sync(function () {
                    var newNameId = self.getNameByValue(classDef.Name).NameID;
                    self.DB.run("update [.classes] set NameID = $NameID where ClassID=$ClassID;", { $NameID: newNameId, ClassID: classDef.ClassID });
                });
            }
        }
        else
            throw new Error("Flexilite.alterClass: class '" + name + "' not found");
    };
    /*
     Create new or alters existing Flexilite class using @name and @classDef as class definition
     */
    SQLiteDataRefactor.prototype.createClass = function (name, classDef) {
        this.alterClass(name, classDef);
    };
    /*
     Drops class and all its data
     */
    SQLiteDataRefactor.prototype.dropClass = function (classID) {
        var self = this;
        var clsDef = self.getClassDefByID(classID);
        self.DB.serialize(function () {
            self.DB.exec("drop table [" + clsDef.Name + "]");
        });
    };
    /*
     Converts set of properties into new object
     */
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
     Removes duplicated objects
     */
    SQLiteDataRefactor.prototype.removeDuplicatedObjects = function (filter, compareFunction, keyProps, replaceTargetNulls) {
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
     Validates property alteration
     */
    SQLiteDataRefactor.prototype.checkAlterClassProperty = function (className, propertyName, propDef, newPropName, limit) {
    };
    /*
     Initializes 'reference' attribute of property definition. Returns referenced class definition
     */
    SQLiteDataRefactor.prototype.initPropReference = function (clsDef, propertyName, propDef) {
        var self = this;
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
                var revPropDef_1 = { reference: {}, rules: { type: 2 /* PROP_TYPE_LINK */ } };
                revPropDef_1.reference.classID = clsDef.ClassID;
                var refClsDef_1 = self.getClassDefByID(propDef.reference.classID);
                self.doCreateClassProperty(refClsDef_1, propDef.reference.$reversePropertyName, revPropDef_1);
            }
            else {
                var revClsDef = self.getClassDefByID(propDef.reference.classID);
                revPropDef.Data.rules.type = 2 /* PROP_TYPE_LINK */;
                self.alterClassProperty(revClsDef.Name, propDef.reference.$reversePropertyName, revPropDef.Data);
            }
            propDef.reference.reversePropertyID = self.getNameByValue(propDef.reference.$reversePropertyName).NameID;
            delete propDef.reference.$reversePropertyName;
        }
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
        return refClsDef;
    };
    /*
     Alters property which new and old types are PROP_TYPE_ENUM. Verifies that enum items to be removed are
     not presented in the database
     */
    SQLiteDataRefactor.prototype.doAlterEnumProp = function (clsDef, propertyId, propertyName, curPropDef, propDef) {
        var self = this;
        if (curPropDef.rules.type === 16 /* PROP_TYPE_ENUM */ && propDef.rules.type === 16 /* PROP_TYPE_ENUM */) {
            if (!propDef.enumDef)
                throw new Error("Enum property " + propertyName + " must have enum items");
            var removedItems = _.differenceWith(curPropDef.enumDef.items, propDef.enumDef.items, function (A, B) {
                return A.ID == B.ID;
            });
            if (removedItems.length > 0) 
            /* There are enum items that are going to be removed. Need to check if there
             existing objects which have one of those enum values
             */
            {
                var checkSQL_1 = "select * from [.ref-values] rv where rv.PropertyID = $PropertyID \n                and rv.ObjectID = (select ObjectID from [.objects] where ClassID = $ClassID) and rv.[Value] in (";
                _.forEach(removedItems, function (A, i) {
                    if (i !== 0)
                        checkSQL_1 += ',';
                    if (_.isString(A.ID))
                        checkSQL_1 += "'" + A.ID + "'";
                    else
                        checkSQL_1 += "" + A.ID;
                });
                checkSQL_1 += ") limit 1;";
                self.DB.serialize(function () {
                    var rows = self.DB.all(checkSQL_1);
                    if (rows.length > 0) {
                        // FIXME clsDef. set CTLO_HASBADDATA
                        var p = {};
                        p.className = self.getNameByID(clsDef.ClassID).Value;
                        p.message = "";
                        self._lastActionReport.push(p);
                    }
                });
            }
        }
    };
    /*
     Applies changes for property that either used to be reference type or switched to be reference type.
     There is also a case when property stays reference but settings have changes (different class, different
     reverse property etc.)
     */
    SQLiteDataRefactor.prototype.doAlterRefProp = function (clsDef, propertyId, propertyName, curPropDef, propDef) {
        var self = this;
        var newRef = false;
        var curRef = false;
        // Determining scope of changes
        if (propDef.rules.type === 2 /* PROP_TYPE_LINK */ || propDef.rules.type === 4 /* PROP_TYPE_OBJECT */) {
            newRef = true;
        }
        if (curPropDef.rules.type === 2 /* PROP_TYPE_LINK */ || curPropDef.rules.type === 4 /* PROP_TYPE_OBJECT */) {
            curRef = true;
        }
        if (!curRef && !newRef)
            return;
        if (newRef) 
        // Convert scalar to reference
        {
            var refClsDef = self.initPropReference(clsDef, propertyName, propDef);
            // Determine ctlv flags
            var ctlv = 0 /* CTLV_NONE */;
            if (propDef.rules.type === 4 /* PROP_TYPE_OBJECT */)
                ctlv |= 4 /* CTLV_REFERENCE_OWN */ | 12 /* CTLV_REFERENCE_DEPENDENT_LINK */;
            else
                ctlv |= 2 /* CTLV_REFERENCE */;
            ctlv |= 1 /* CTLV_INDEX */;
            var cltvMask = !15 /* CTLV_REFERENCE_MASK */;
            var idPropID = self.findIdOrCodeProperty(refClsDef);
            var pn = idPropID ? self.getNameByID(idPropID).Value : 'rowid';
            var sql = "insert or replace into [.ref-values] (ObjectID, PropertyID, PropIndex, ctlv, [Value], ExtData) \n                select rv.ObjectID, rv.PropertyID, rv.PropIndex, \n                (rv.ctlv & $ctlvMask) | $ctlv, \n                rf.rowid, \n                rv.ExtData from [.ref-values] rv\n                join [.objects] o on o.ObjectID = rv.ObjectID and o.Class = $ClassID\n                join [" + refClsDef.Name + "] rf on rf.[" + pn + "] = rv.[Value]\n                where rv.PropertyID = $PropertyID;";
            self.DB.run.sync(self.DB, sql, {
                $PropertyID: propertyId,
                $ctlv: ctlv,
                $cltvMask: cltvMask,
                $ClassID: clsDef.ClassID
            });
        }
        else 
        // Convert reference to scalar
        {
            // Delete reverse property if it exists
            if (curPropDef.reference.reversePropertyID) {
                // TODO Trigger on .class_properties to delete entry from .classes.Data.properties, by property ID
                var sql_1 = "delete from [.class_properties] where PropertyID = $PropertyID;";
                self.DB.run(sql_1, { $PropertyID: curPropDef.reference.reversePropertyID });
            }
            var ctlv = 0 /* CTLV_NONE */;
            var cltvMask = !15 /* CTLV_REFERENCE_MASK */;
            var refClsDef = self.getClassDefByID(curPropDef.reference.classID);
            var idPropID_1 = self.findIdOrCodeProperty(refClsDef);
            var pn = idPropID_1 ? self.getNameByID(idPropID_1).Value : 'rowid';
            var sql = "insert or replace into [.ref-values] (ObjectID, PropertyID, PropIndex, ctlv, [Value], ExtData) \n                select rv.ObjectID, rv.PropertyID, rv.PropIndex, \n                (rv.ctlv & $ctlvMask) | $ctlv, \n                rf.rowid, \n                rv.ExtData from [.ref-values] rv\n                join [.objects] o on o.ObjectID = rv.ObjectID and o.Class = $ClassID\n                join [" + refClsDef.Name + "] rf on rf.[" + pn + "] = rv.[Value]\n                where rv.PropertyID = $PropertyID;";
            self.DB.run.sync(self.DB, sql, {
                $PropertyID: propertyId,
                $ctlv: ctlv,
                $cltvMask: cltvMask,
                $ClassID: clsDef.ClassID
            });
        }
    };
    /*

     */
    SQLiteDataRefactor.prototype.findIdOrCodeProperty = function (refClsDef) {
        var idPropID;
        // Check if it has property with role ID or Code
        var idProp = _.find(refClsDef.Data.properties, function (pd, pID) {
            if ((pd.role & 4 /* PROP_ROLE_ID */) != 0) {
                idPropID = pID;
                return true;
            }
            return false;
        });
        if (!idProp) {
            idProp = _.find(refClsDef.Data.properties, function (pd, pID) {
                if ((pd.role & 8 /* PROP_ROLE_CODE */) != 0) {
                    idPropID = pID;
                    return true;
                }
                return false;
            });
        }
        return idPropID ? Number(idPropID) : null;
    };
    /*
     Internal function for altering individual property. Applies changes directly to clsDef.properties
     but does not start transaction, does not update [.class_properties].
     When applying changes, tries to minimize amount of updates on DB.
     Cases:
     1) scalar to scalar. Existing values are validated against new property definition.
     Values get changed if re-indexing is required
     2) scalar to reference. Existing values are treated as IDs/Codes/ObjectIDs. Values get changed and indexes
     3) reference to scalar. Existing references are converted to IDs/Codes/ObjectIDs. Values get changed
     4) reference to reference (different class, different reverseProperty)
     This kind of alteration is not supported and should be processed in few steps: reference->scalar->possible ID alterations
     ->reference.

     Values get updated based on kind of property changes. (normally, only when new indexing is defined, [.ref-values])
     Idea is to avoid non-mandatory massive updates, whenever possible
     */
    SQLiteDataRefactor.prototype.doAlterClassProperty = function (clsDef, propertyName, propDef, newPropName) {
        var self = this;
        var propRow = _.find(clsDef.Properties, function (prop, idx) {
            return prop.Name === propertyName;
        });
        if (propDef.$renameTo) 
        // $renameTo has priority over newPropName
        {
            newPropName = propDef.$renameTo;
            delete propDef.$renameTo;
        }
        if (newPropName) {
            propRow.NameID = self.getNameByValue(newPropName).NameID;
        }
        var curPropDef = clsDef.Data.properties[propRow.PropertyID];
        var propUpdRequired = false;
        //
        var newRef = false;
        var curRef = false;
        // Determining scope of changes
        if (propDef.rules.type === 2 /* PROP_TYPE_LINK */ || propDef.rules.type === 4 /* PROP_TYPE_OBJECT */) {
            newRef = true;
        }
        if (curPropDef.rules.type === 2 /* PROP_TYPE_LINK */ || curPropDef.rules.type === 4 /* PROP_TYPE_OBJECT */) {
            curRef = true;
        }
        if (newRef && curRef) {
            throw new Error("Cannot change definition of reference property " + propertyName + ". \nIts definition has to be converted to scalar first, and then to new reference definition.");
        }
        if (curRef || newRef) {
            propUpdRequired = true;
            self.doAlterRefProp(clsDef, propRow.PropertyID, propertyName, curPropDef, propDef);
            return;
        }
        // Compare index definition change
        var updState = SQLiteDataRefactor.getCtlvFromPropertyDef(propDef, propRow.ctlv);
        if (updState.updateRequired) {
            // TODO Convert value if needed
            var updSql = "update [.ref-values] set ctlv = $ctlv,\n             [Value] = [Value]\n             where PropertyID = $PropertyID and ObjectID = (select ObjectID from [.objects] where ClassID = $ClassID);";
            self.DB.run.sync(self.DB, updSql, {
                $PropertyID: propRow.PropertyID,
                $ctlv: updState.ctlv,
                $ClassID: clsDef.ClassID
            });
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
        /*
         Indexed is treated after unique index constraint.
         result of this change is that flag CTLV_INDEXED is set or cleared. Index gets updated automatically
         as part of ctlv flags update
         */
        /*
         Similarly to indexed flag, this attribute leads to update of CTLV_FULL_TEXT_INDEX flag.
         If this flag is set, trigger on [.ref-values] will update/insert/delete [.full_text_data] table.
         If this flag is cleared on property definition, no changes are applied to actual indexing, but
         all new updates/inserts will be ignoring full text index update. When flag toggles from true to
         false, property definition ctlv gets flag CTLV_USED_FULL_TEXT_INDEX flag which indicates that
         some property values might be indexed via full text index, and MATCH function will apply both
         full text search and linear search
         */
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
     Alters single class property definition. Handles both creation and alteration of property
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
        self.doSaveClassDef(clsDef);
    };
    /*
     Internal method to save class definition into database ([.classes] table)
     */
    SQLiteDataRefactor.prototype.doSaveClassDef = function (clsDef) {
        var self = this;
        self.DB.serialize(function () {
            self.DB.run("update [.classes] set Data = $Data where ClassID = $ClassID;", {
                $ClassID: clsDef.ClassID,
                $Data: JSON.stringify(clsDef.Data)
            });
        });
    };
    /*

     */
    SQLiteDataRefactor.getCtlvFromPropertyDef = function (propDef, oldCtlv) {
        var result = { ctlv: 0 /* CTLV_NONE */, updateRequired: false };
        // Initial value for ctlv is new type
        result.ctlv = propDef.rules.type;
        if ((propDef.role && ((propDef.role & 8 /* PROP_ROLE_CODE */) != 0
            || (propDef.role & 4 /* PROP_ROLE_ID */) != 0)) || propDef.unique)
            result.ctlv |= 64 /* CTLV_UNIQUE_INDEX */;
        if (propDef.indexed)
            result.ctlv |= 1 /* CTLV_INDEX */;
        if (propDef.fastTextSearch)
            result.ctlv |= 256 /* CTLV_FULL_TEXT_INDEX */;
        if (propDef.noTrackChanges)
            result.ctlv |= 128 /* CTLV_NO_TRACK_CHANGES */;
        if ((result.ctlv & oldCtlv) !== result.ctlv)
            result.updateRequired = true;
        return result;
    };
    /*
     Internal method to create a new class property (property must not exist).
     New row will be inserted into [.class_properties] table, [.classes].Data.properties definition will be updated,
     but class itself will not be saved.
     */
    SQLiteDataRefactor.prototype.doCreateClassProperty = function (clsDef, propertyName, propDef) {
        var self = this;
        // Get name ID
        var pnID = self.getNameByValue(propertyName).NameID;
        var ctlvArgs = SQLiteDataRefactor.getCtlvFromPropertyDef(propDef, 0 /* CTLV_NONE */);
        self.DB.serialize(function () {
            self.DB.run("insert into [.class_properties] (ClassID, NameID, ctlv) values ($ClassID, $NameID, $ctlv);", { $ClassID: clsDef.ClassID, $NameID: pnID, $ctlv: ctlvArgs.ctlv });
            var rows = self.DB.all("select last_insert_rowid();");
            var propID = rows[0].rowid;
            // Clean up temporary attributes in property definition
            delete propDef.$rangeDef;
            delete propDef.$renameTo;
            if (propDef.reference) {
                delete propDef.reference.$className;
                delete propDef.reference.$reversePropertyName;
            }
            clsDef.Data.properties[propID] = propDef;
        });
    };
    SQLiteDataRefactor.prototype.getInvalidObjects = function (className, markAsInvalid) {
        // TODO
        return null;
    };
    /*
     Creates a new class property. Internally calls alter class property, which does all the job
     */
    SQLiteDataRefactor.prototype.createClassProperty = function (className, propertyName, propDef) {
        this.alterClassProperty(className, propertyName, propDef);
    };
    /*
     Deletes class property definition. Does not update existing values (they become kind of 'orphaned')
     */
    SQLiteDataRefactor.prototype.dropClassProperty = function (classID, propertyName) {
        var self = this;
        self.DB.serialize(function () {
            self.DB.run("delete from [.class_properties] where PropertyID = $PropertyID");
        });
    };
    /*
     Synchronizes node-orm model to .classes and .class_properties.
     Makes updates to the database.
     Returns instance of ICollectionDef, with all changes applied
     NOTE: this function is intended to run inside Syncho wrapper
     */
    /*
     Links in doc:
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
        // They come as Dictionary of IClassPropertyDef by property name and
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

         4. Check if there are some properties which switch from BOXED_OBJECT to FKEY ->
         process them by creating new objects, copy property values, delete properties from existing records
         5. Delete obsolete properties
         6. Insert or replace new/existing properties
         7. Update class: Data, Hash
         */
        // Initialize
        vars.existingProps = {}; // Dictionary by property name
        vars.propsToDelete = []; // Array of properties
        vars.newProps = {}; // Dictionary by property name
        // Init items for [.class_properties]
        _.forEach(vars.converter.targetClassProps, function (p, n) {
            var nameID = self.getNameByValue(n).NameID;
            var np = {};
            np.NameID = nameID;
            np.ctlv = 0 /* CTLV_NONE */;
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
        self.initAndSaveProperties(self, vars);
        // Now vars.newProps are saved and have property IDs assigned
        // Set class properties
        // ctloMask
        vars.classDef.ctloMask = 0 /* CTLO_NONE */;
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
                np.ctlv |= 64 /* CTLV_UNIQUE_INDEX */;
            }
            else if (p.indexed) {
                np.ctlv |= 1 /* CTLV_INDEX */;
            }
            if (p.fastTextSearch) {
                np.ctlv |= 256 /* CTLV_FULL_TEXT_INDEX */;
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
        var clsID = self.DB.all.sync(self.DB, "insert or replace into [.classes] (NameID, BaseSchemaID, ctloMask) \n                values ($NameID, $ctloMask); select last_insert_rowid();", {
            $NameID: vars.classDef.NameID,
            $ctloMask: vars.classDef.ctloMask,
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
    return SQLiteDataRefactor;
}());
exports.SQLiteDataRefactor = SQLiteDataRefactor;
//# sourceMappingURL=SQLiteDataRefactor.js.map