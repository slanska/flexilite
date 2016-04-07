/**
 * Created by slanska on 2016-01-16.
 */
"use strict";
var objectHash = require('object-hash');
var SchemaHelper_1 = require('../../misc/SchemaHelper');
var SQLiteDataRefactor = (function () {
    function SQLiteDataRefactor(DB) {
        this.DB = DB;
        this._lastActionReport = '';
    }
    SQLiteDataRefactor.prototype.boxedObjectToLinkedObject = function (classID, refPropID) {
    };
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
    SQLiteDataRefactor.prototype.getClassDefByID = function (classID) {
        var self = this;
        var rows = self.DB.all.sync(self.DB, "select * from [.classes] where ClassID = $ClassID limit 1", { $ClassID: classID });
        return self.getClassDefFromRows(rows);
    };
    /*

     */
    SQLiteDataRefactor.prototype.getNameByValue = function (name) {
        var rows = this.DB.run.sync(this.DB, "insert or ignore into [.names] ([Value]) values ($name);\n            select * from [.names] where [Value] = $name limit 1", { $name: name });
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
    SQLiteDataRefactor.prototype.getLastActionReport = function () {
        return this._lastActionReport;
    };
    SQLiteDataRefactor.prototype.alterClass = function (classID, newClassDef, newSchemaDef, newName) {
        var self = this;
        // Check if class exists
        var classDef = self.getClassDefByID(classID);
        if (classDef) {
        }
        else
            throw new Error("Flexilite.alterClass: class with ID '" + classID + "' not found");
    };
    /*

     */
    SQLiteDataRefactor.prototype.applyClassDefinition = function (classDef, schemaDef) {
        var self = this;
        // Regenerate view if needed
        // Check if class schema needs synchronization
        if (!classDef.ViewOutdated) {
            return;
        }
        var viewName = self.getNameByID(classDef.ClassID).Value;
        var viewSQL = "drop view if exists [" + viewName + "];\n            \ncreate view if not exists " + viewName + " as select\n            [ObjectID]";
        // Process properties
        var propIdx = 0;
        _.forEach(classDef.Properties, function (p, propID) {
            if (propIdx > 0)
                viewSQL += ', ';
            propIdx++;
            var propName = self.getNameByID(p.NameID);
            if (p.ColumnAssigned) 
            // This property is stored directly in .objects table
            {
                viewSQL += "o.[" + p.ColumnAssigned + "] as [" + propName + "]\n";
            }
            else 
            // This property is stored in Values table. Need to use subquery for access
            {
                viewSQL += "\n(select v.[Value] from [.values] v\n                    where v.[ObjectID] = o.[ObjectID]\n    and v.[PropIndex] = 0 and v.[PropertyID] = " + p.PropertyID;
                if ((p.ctlv & 1) === 1)
                    viewSQL += " and (v.[ctlv] & 1 = 1)";
                viewSQL += ") as [" + propName + "]";
            }
        });
        // non-schema properties are returned as single JSON
        //if (propIdx > 0)
        //    viewSQL += ', ';
        //
        //viewSQL += ` as [.non-schema-props]`;
        viewSQL += " from [.objects] o\n    where o.[ClassID] = " + classDef.ClassID;
        if (classDef.ctloMask !== 0)
            viewSQL += "and ((o.[ctlo] & " + classDef.ctloMask + ") = " + classDef.ctloMask + ")";
        viewSQL += ';\n';
        // Insert trigger when ObjectID or HostID is null.
        // In this case, recursively call insert statement with newly obtained ObjectID
        viewSQL += self.generateTriggerBegin(viewName, 'insert', 'whenNull', 'when new.[ObjectID] is null or new.[HostID] is null');
        // Generate new ID
        viewSQL += "insert or replace into [.generators] (name, seq) select '.objects',\n                coalesce((select seq from [.generators] where name = '.objects') , 0) + 1 ;";
        viewSQL += "insert into [" + viewName + "] ([ObjectID], [HostID]";
        var cols = '';
        _.forEach(classDef.Properties, function (p, propID) {
            var propName = self.getNameByID(p.NameID).Value;
            viewSQL += ", [" + propName + "]";
            cols += ", new.[" + propName + "]";
        });
        // HostID is expected to be either (a) ID of another (hosting) object
        // or (b) 0 or null - means that object will be self-hosted
        viewSQL += ") select\n            [NextID],\n             case\n                when new.[HostID] is null or new.[HostID] = 0 then [NextID]\n                else new.[HostID]\n             end\n\n             " + cols + " from\n             (SELECT coalesce(new.[ObjectID],\n             (select (seq)\n          FROM [.generators]\n          WHERE name = '.objects' limit 1)) AS [NextID])\n\n             ;\n";
        viewSQL += "end;\n";
        // Insert trigger when ObjectID is not null
        viewSQL += self.generateTriggerBegin(viewName, 'insert', 'whenNotNull', 'when not (new.[ObjectID] is null or new.[HostID] is null)');
        viewSQL += self.generateConstraintsForTrigger(viewName, classDef);
        viewSQL += "insert into [.objects] ([ObjectID], [ClassID], [ctlo]";
        cols = '';
        for (var propID in classDef.Data.properties) {
            var p = classDef.Properties[propID];
            var propName = self.getNameByID(p.NameID).Value;
            // if column is assigned
            if (p.ColumnAssigned) {
                viewSQL += ", [" + p.ColumnAssigned + "]";
                cols += ", new.[" + propName + "]";
            }
        }
        viewSQL += ") values (new.HostID << 31 | (new.ObjectID & 2147483647),\n             " + classDef.ClassID + ", " + classDef.ctloMask + cols + ");\n";
        viewSQL += self.generateInsertValues(classDef.ClassID, classDef);
        viewSQL += 'end;\n';
        // Update trigger
        viewSQL += self.generateTriggerBegin(viewName, 'update');
        viewSQL += self.generateConstraintsForTrigger(viewName, classDef);
        var columns = '';
        _.forEach(classDef.Properties, function (p, propID) {
            // if column is assigned
            if (p.ColumnAssigned) {
                var propName = self.getNameByID(p.NameID).Value;
                if (columns !== '')
                    columns += ',';
                columns += "[" + p.ColumnAssigned + "] = new.[" + propName + "]";
            }
        });
        if (columns !== '') {
            viewSQL += "update [.objects] set " + columns + " where [ObjectID] = new.[ObjectID];\n";
        }
        viewSQL += self.generateInsertValues(classDef.ClassID, classDef);
        viewSQL += self.generateDeleteNullValues(classDef.Data);
        viewSQL += 'end;\n';
        // Delete trigger
        viewSQL += self.generateTriggerBegin(viewName, 'delete');
        viewSQL += "delete from [.objects] where [ObjectID] = new.[ObjectID] and [CollectionID] = " + classDef.ClassID + ";\n";
        viewSQL += 'end;\n';
        console.log(viewSQL);
        // Run view script
        self.DB.exec.sync(self.DB, viewSQL);
    };
    /*

     */
    SQLiteDataRefactor.prototype.generateDeleteNullValues = function (classDef) {
        var result = '';
        // Iterate through all properties
        _.forEach(classDef.properties, function (p, propID) {
            //
            //if (!p.ColumnAssigned)
            //{
            //    result += `delete from [.values] where [ObjectID] = (old.ObjectID | (old.HostID << 31)) and [PropertyID] = ${p.PropertyID}
            //    and [PropIndex] = 0 and [ClassID] = ${classDef.ClassID} and new.[${p.PropertyName}] is not null;\n`;
            //}
        });
        return result;
    };
    /*
     Generates beginning of INSTEAD OF trigger for dynamic view
     */
    SQLiteDataRefactor.prototype.generateTriggerBegin = function (viewName, triggerKind, triggerSuffix, when) {
        if (triggerSuffix === void 0) { triggerSuffix = ''; }
        if (when === void 0) { when = ''; }
        return "/* Autogenerated code. Do not edit or delete. " + (viewName[0].toUpperCase() + viewName.slice(1)) + "." + triggerKind + " trigger*/\n\n            drop trigger if exists [trig_" + viewName + "_" + triggerKind + triggerSuffix + "];\n    create trigger if not exists [trig_" + viewName + "_" + triggerKind + triggerSuffix + "] instead of " + triggerKind + " on [" + viewName + "]\n    for each row\n\n    " + when + "\n    begin\n";
    };
    /*
     Generates constraints for INSTEAD OF triggers for dynamic view
     */
    SQLiteDataRefactor.prototype.generateConstraintsForTrigger = function (className, classDef) {
        var result = '';
        // Iterate through all properties
        _.forEach(classDef.Data.properties, function (p, propID) {
            // TODO Get property name by ID
            // Is required/not null?
            if (p.rules.minOccurences > 0)
                result += "when new.[" + propID + "] is null then '" + propID + " is required'\n";
            // Is unique
            // TODO Unique in Class.Property, unique in Property (all classes)
            //         if (p.Unique)
            //             result += `when exists(select 1 from [${collectionName}] v where v.[ObjectID] <> new.[ObjectID]
            // and v.[${propName}] = new.[${propName}]) then '${propName} has to be unique'\n`;
            // Range validation
            // Max length validation
            if ((p.rules.maxLength || 0) !== 0 && (p.rules.maxLength || 0) !== -1)
                result += "when typeof(new.[" + propID + "]) in ('text', 'blob')\n        and len(new.[" + propID + "] > " + p.rules.maxLength + ") then 'Length of " + propID + " exceeds max value of " + p.rules.maxLength + "'\n";
            // Regex validation
            // TODO Use extension library for Regex
            // TODO Other validation rules?
        });
        if (result.length > 0) {
            result = "select raise_error(ABORT, s.Error) from (select case " + result + " else null end as Error) s where s.Error is not null;\n";
        }
        return result;
    };
    /*

     */
    SQLiteDataRefactor.prototype.generateInsertValues = function (collectionID, classDef) {
        var self = this;
        var result = '';
        // Iterate through all properties
        _.forEach(classDef.Properties, function (p, propID) {
            var propName = self.getNameByID(p.NameID).Value;
            if (!p.ColumnAssigned) {
                result += "insert or replace into [Values] ([ObjectID], [ClassID], [PropertyID], [PropIndex], [ctlv], [Value])\n             select (new.ObjectID | (new.HostID << 31)), " + collectionID + ", " + p.PropertyID + ", 0, " + p.ctlv + ", new.[" + propName + "]\n             where new.[" + propName + "] is not null;\n";
            }
        });
        return result;
    };
    /*

     */
    SQLiteDataRefactor.prototype.createClass = function (name, classDef, schemaDef) {
        var self = this;
        // TODO classDef = self.getClassDefByName(name);
        if (classDef) {
            /// TODO
            return;
        }
    };
    SQLiteDataRefactor.prototype.dropClass = function (classID) {
    };
    SQLiteDataRefactor.prototype.plainPropertiesToBoxedObject = function (classID, propIDs, newRefProp, filter, targetClassID) {
    };
    SQLiteDataRefactor.prototype.plainPropertiesToLinkedObject = function (classID, propIDs, newRefProp, filter, targetClassID, updateData, sourceKeyPropID, targetKeyPropID) {
    };
    SQLiteDataRefactor.prototype.boxedObjectToPlainProperties = function (classID, refPropID, filter, propMap) {
    };
    SQLiteDataRefactor.prototype.linkedObjectToPlainProps = function (classID, refPropID, filter, propMap) {
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

     */
    SQLiteDataRefactor.prototype.generateView = function (classID) {
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
    SQLiteDataRefactor.prototype.generateClassAndSchemaDefForSync = function (model) {
        var self = this;
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
        vars.schemaData = { Data: { properties: {} } }; // future Schema.Data
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
            self.saveNewClass(self, vars, model);
        }
        this.initExistingColAssignment(vars);
        self.initAndSaveProperties(self, vars);
        // Now vars.newProps are saved and have property IDs assigned
        // Set column assignments
        _.forEach(vars.newProps, function (p, id) {
            var prior = 0;
            prior = self.determineColAssignmentPriority(p.Data, id);
            if (prior !== 0) {
                // Try to find available columns
                _.forEach(vars.columnAssignments, function (ca, col) {
                    if (ca.propID && ca.propID !== id && ca.priority < prior) {
                    }
                });
            }
        });
        // Set class properties
        // Check if
        self.initSchemaData(self, vars, model);
        self.prepareSchemaData(self, vars);
        self.saveSchema(self, vars, classNameID);
        return { Class: vars.classDef, Schema: vars.schemaData };
    };
    /*

     */
    SQLiteDataRefactor.prototype.initExistingColAssignment = function (vars) {
        // Set column assignment
        var cols = 'ABCDEFGHIJ';
        for (var c = 0; c < cols.length; c++) {
            var pid = vars.classDef[cols[c]];
            var prior = 0;
            if (pid) {
                prior = this.determineColAssignmentPriority(vars.classDef.Data.properties[pid], pid);
            }
            vars.columnAssignments[c] = { propID: pid, priority: prior };
        }
    };
    /*

     */
    SQLiteDataRefactor.prototype.determineColAssignmentPriority = function (cp, pid) {
        var prior = 0;
        if (cp.role & 4 /* ID */)
            prior = 100;
        else if (cp.role & 8 /* Code */)
            prior = 90;
        else if (cp.unique)
            prior = 80;
        else if (cp.indexed)
            prior = 70;
        else {
            switch (cp.rules.type) {
                case 7 /* BINARY */:
                case 11 /* JSON */:
                case 12 /* LINK */:
                case 5 /* OBJECT */:
                    prior = 0;
                    break;
                default:
                    if (cp.rules.maxOccurences === 1 && cp.rules.minOccurences === 1)
                        prior = 60;
                    else
                        prior = 50;
            }
        }
        return prior;
    };
    SQLiteDataRefactor.prototype.initSchemaData = function (self, vars, model) {
        if (!vars.schemaData) {
            // Schema match not found. Create new one
            var sql = "insert into [.schemas] into (NameID, Data, Hash) values ($NameID, $Data, $Hash);\n            select last_insert_rowid();";
            var rows = self.DB.all.sync(self.DB, sql, {
                $NameID: self.getNameByValue(model.table).NameID,
                $Data: JSON.stringify(vars.schemaData.Data),
                $Hash: objectHash(vars.schemaData.Data)
            });
            vars.schemaData = rows[0];
        }
        else {
        }
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
    SQLiteDataRefactor.prototype.saveNewClass = function (self, vars, model) {
        vars.classDef = {};
        vars.classDef.NameID = self.getNameByValue(model.table).NameID;
        // Skip BaseSchemaID now - will set it later
        vars.classDef.ctloMask = 0; // TODO
        // TODO set later: vars.classDef.Data = {properties: vars.newProps};
        //vars.classDef.Hash = objectHash(vars.classDef.Data);
        var clsID = self.DB.all.sync(self.DB, "insert or replace into [.classes] (NameID, BaseSchemaID, ctloMask, A, B, C, D, E, F, G, H, I, J) \n                values ($NameID, $BaseSchemaID, $ctloMask, $A, $B, $C, $D, $E, $F, $G, $H, $I, $J); select last_insert_rowid();", {
            $NameID: vars.classDef.NameID,
            $BaseSchemaID: vars.classDef.BaseSchemaID,
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
    SQLiteDataRefactor.prototype.saveSchema = function (self, vars, classNameID) {
        self.DB.run.sync(self.DB, "insert or replace into [.schemas] (SchemaID, NameID, Hash, Data) \n                values ($SchemaID, $NameID, $Hash, $Data);", {
            $SchemaID: vars.schemaData.SchemaID,
            $NameID: classNameID,
            $Hash: objectHash(vars.schemaData.Data),
            $Data: JSON.stringify(vars.schemaData.Data)
        });
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
    /*
     Converts schema data from Dictionary<name:string> to Dictionary<nameID>
     */
    SQLiteDataRefactor.prototype.prepareSchemaData = function (self, vars) {
        _.forEach(vars.converter.targetSchema, function (p, n) {
            var nameID = self.getNameByValue(n).NameID;
            vars.schemaData.Data.properties[nameID] = p;
        });
        // Check if this schema is already defined.
        // By schema signature
        var hashValue = objectHash(vars.schemaData);
        var schemas = self.DB.all.sync(self.DB, "select * from [.schemas] where Hash = $hash and NameID = $classNameID", { hash: hashValue, NameID: vars.classDef.NameID });
        var foundSchema = _.find(schemas, function (item) {
            if (_.isEqual(item.Data, vars.schemaData.Data)) {
                vars.schemaData = item;
                return true;
            }
        });
    };
    return SQLiteDataRefactor;
}());
exports.SQLiteDataRefactor = SQLiteDataRefactor;
//# sourceMappingURL=SQLiteDataRefactor.js.map