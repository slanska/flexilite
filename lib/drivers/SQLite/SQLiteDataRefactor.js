/**
 * Created by slanska on 2016-01-16.
 */
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports", 'sqlite3', '../../misc/SchemaHelper', '../../misc/reverseEng'], factory);
    }
})(function (require, exports) {
    "use strict";
    ///<reference path="../../../typings/lib.d.ts"/>
    ///<reference path="DBInterfaces.d.ts"/>
    var sqlite3 = require('sqlite3');
    var SchemaHelper_1 = require('../../misc/SchemaHelper');
    var Sync = require('syncho');
    var reverseEng_1 = require('../../misc/reverseEng');
    var SQLiteDataRefactor = (function () {
        function SQLiteDataRefactor(DB) {
            this.DB = DB;
            this._lastActionReport = '';
        }
        /*
    
         */
        SQLiteDataRefactor.prototype.importFromDatabase = function (options) {
            var _this = this;
            Sync(function () {
                var srcDB = _this.DB;
                var srcTbl = options.sourceTable || options.targetTable;
                if (options.sourceConnectionString) {
                    srcDB = new sqlite3.Database(options.sourceConnectionString);
                    if (_.isEmpty(srcTbl))
                        srcTbl = options.targetTable;
                }
                else {
                    if (srcTbl === options.targetTable)
                        throw new Error("Source and target tables cannot be the same");
                }
                // Check if target flexitable exists
                var clsDef = _this.getClassDefByName(options.targetTable);
                // load metadata for source table
                var reng = new reverseEng_1.ReverseEngine(srcDB);
                var srcMeta = reng.loadSchemaFromDatabase();
                var syncOptions = srcMeta[srcTbl];
                if (!clsDef) {
                    var schemaHlp = new SchemaHelper_1.SchemaHelper(_this.DB, syncOptions);
                    schemaHlp.convertFromNodeOrmSync();
                }
                // If flexitable already exists: check if there are source properties
                // not mapped and not existing in the target table. These properties will
                // be created
                if (clsDef) {
                    _.forEach(syncOptions.properties, function (srcProp, srcPropName) {
                        var targetPropName = srcPropName;
                        if (options.columnPropMap[srcPropName]) {
                        }
                    });
                }
            });
        };
        /*
    
         */
        SQLiteDataRefactor.prototype.boxedObjectToLinkedObject = function (classID, refPropID) {
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
        SQLiteDataRefactor.prototype.alterClass = function (classID, newClassDef, newName) {
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
        SQLiteDataRefactor.prototype.applyClassDefinition = function (classDef) {
            var self = this;
            // var viewName = self.getNameByID(classDef.ClassID).Value;
            // if (viewName[0] === '.')
            //     throw new Error(`Invalid class name ${viewName}. Class name may not start from dot ('.')`);
            //
            // var viewSQL = `drop view if exists [${viewName}];
            //     \ncreate view if not exists ${viewName} as select
            //     [ObjectID]`;
            //
            // Init column assignment map
            // let colMap = {} as{[propID:number]:string};
            // for (let idx = 0; idx < SQLiteDataRefactor.COLUMN_LETTERS.length; idx++)
            // {
            //     let ch = SQLiteDataRefactor.COLUMN_LETTERS[idx];
            //     let propID = classDef[ch];
            //     if (propID)
            //     {
            //         colMap[propID] = ch;
            //     }
            // }
            // Process properties
            // var propIdx = 0;
            // _.forEach(classDef.Properties, (p:IFlexiClassProperty, propID:number)=>
            // {
            //     if (propIdx > 0)
            //         viewSQL += ', ';
            //     propIdx++;
            //
            //     let propName = self.getNameByID(p.NameID).Value;
            //
            //     let colLetter = colMap[p.PropertyID];
            //     if (colLetter)
            //     // This property is stored directly in .objects table in A..J columns
            //     {
            //         viewSQL += `o.[${colLetter}] as [${propName}]\n`;
            //     }
            //     else
            //     {
            //         viewSQL += `flexi_get(${p.PropertyID}, o.[ObjectID], s.[Data], o.[Data]`;
            //         if (p.Data.defaultValue)
            //         {
            //             if (_.isString(p.Data.defaultValue))
            //                 viewSQL += `'${p.Data.defaultValue}'`;
            //             else viewSQL += `${p.Data.defaultValue}`;
            //         }
            //         viewSQL += `) as [${propName}]\n`;
            //     }
            // });
            //     viewSQL += `, o.[Data] as [.json-data] from [.objects] o join [.schemas] s on o.SchemaID = s.SchemaID
            // where o.[ClassID] = ${classDef.ClassID}`;
            //
            //     if (classDef.ctloMask !== 0)
            //         viewSQL += `and ((o.[ctlo] & ${classDef.ctloMask}) = ${classDef.ctloMask})`;
            //
            //     viewSQL += ';\n';
            //
            //     // Insert trigger when ObjectID is null.
            //     // In this case, recursively call insert statement with newly obtained ObjectID
            //     viewSQL += self.generateTriggerBegin(viewName, 'insert', 'whenNull',
            //         'when new.[ObjectID] is null ');
            //
            //     // Generate new ID
            //     viewSQL += `insert or replace into [sqlite_sequence] (name, seq) select '.objects',
            //             coalesce((select seq from [sqlite_sequence] where name = '.objects'), 0) + 1;`;
            //     viewSQL += `insert into [${viewName}] ([ObjectID]`;
            //
            //     var cols = '';
            //     _.forEach(classDef.Properties, (p, propID)=>
            //     {
            //         let propName = self.getNameByID(p.NameID).Value;
            //         viewSQL += `, [${propName}]`;
            //         cols += `, new.[${propName}]`;
            //     });
            //
            //     // HostID is expected to be either (a) ID of another (hosting) object
            //     // or (b) 0 or null - means that object will be self-hosted
            //     viewSQL += `) select
            //         [NextID],
            //          ${cols} from
            //          (SELECT coalesce(new.[ObjectID],
            //          (select (seq)
            //       FROM [sqlite_sequence]
            //       WHERE name = '.objects' limit 1)) AS [NextID])
            //          ;\n`;
            //     viewSQL += `end;\n`;
            //
            //     // Insert trigger when ObjectID is not null
            //     viewSQL += self.generateTriggerBegin(viewName, 'insert', 'whenNotNull',
            //         'when new.[ObjectID] is not null');
            //     viewSQL += self.generateConstraintsForTrigger(viewName, classDef);
            //
            //     viewSQL += `insert into [.objects] ([ObjectID], [ClassID], [ctlo], [Data]`;
            //     cols = '';
            //     let jsonData = `json_set({}`;
            //     for (var propID in classDef.Data.properties)
            //     {
            //         var p:IFlexiClassProperty = classDef.Properties[propID];
            //         let propName = self.getNameByID(p.NameID).Value;
            //
            //         let colLetter = colMap[p.PropertyID];
            //         // if column is assigned
            //         if (colLetter)
            //         {
            //             viewSQL += `, [${colLetter}]`;
            //             cols += `, flexi_json_value(new.[${propName}])`;
            //         }
            //         else
            //         {
            //             let jsp = schemaDef.Data.properties[propID].map.jsonPath;
            //             jsonData += `, '$${jsp}', new.[${propName}]`;
            //         }
            //     }
            //
            //     viewSQL += `) values (new.ObjectID,
            //          ${classDef.ClassID}, ${classDef.ctloMask}${cols},
            //          ${jsonData}));\n`;
            //
            //     viewSQL += self.generateInsertValues(classDef.ClassID, classDef);
            //     viewSQL += 'end;\n';
            //
            //     // Update trigger
            //     viewSQL += self.generateTriggerBegin(viewName, 'update');
            //     viewSQL += self.generateConstraintsForTrigger(viewName, classDef);
            //
            //     var columns = '';
            //     _.forEach(classDef.Properties, (p, propID)=>
            //     {
            //         let colLetter = colMap[p.PropertyID];
            //         // if column is assigned
            //         if (colLetter)
            //         {
            //             let propName = self.getNameByID(p.NameID).Value;
            //             if (columns !== '')
            //                 columns += ',';
            //             columns += `[${colLetter}] = new.[${propName}]`;
            //         }
            //     });
            //     if (columns !== '')
            //     {
            //         viewSQL += `update [.objects] set ${columns} where [ObjectID] = new.[ObjectID];\n`;
            //     }
            //
            //     viewSQL += self.generateInsertValues(classDef.ClassID, classDef);
            //     viewSQL += self.generateDeleteNullValues(classDef.Data);
            //     viewSQL += 'end;\n';
            //
            //     // Delete trigger
            //     viewSQL += self.generateTriggerBegin(viewName, 'delete');
            //     viewSQL += `delete from [.objects] where [ObjectID] = new.[ObjectID] and [CollectionID] = ${classDef.ClassID};\n`;
            //     viewSQL += 'end;\n';
            //
            //     console.log(viewSQL);
            //
            //     // Run view script
            //     self.DB.exec.sync(self.DB, viewSQL);
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
        SQLiteDataRefactor.prototype.generateInsertValues = function (classID, classDef) {
            var self = this;
            var result = '';
            // Iterate through all properties
            _.forEach(classDef.Properties, function (p, propID) {
                var propName = self.getNameByID(p.NameID).Value;
                if (!p.ColumnAssigned) {
                    result += "insert or replace into [Values] ([ObjectID], [ClassID], [PropertyID], [PropIndex], [ctlv], [Value])\n             select (new.ObjectID, " + classID + ", " + p.PropertyID + ", 0, " + p.ctlv + ", new.[" + propName + "]\n             where new.[" + propName + "] is not null;\n";
                }
            });
            return result;
        };
        /*
    
         */
        SQLiteDataRefactor.prototype.createClass = function (name) {
            var self = this;
            var classDef = self.getClassDefByName(name);
            if (classDef) {
                /// TODO
                return;
            }
        };
        SQLiteDataRefactor.prototype.dropClass = function (classID) {
        };
        SQLiteDataRefactor.prototype.plainPropertiesToBoxedObject = function (classID, newRefProp, targetClassID, propMap, filter) {
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
        // private getSchemaByID(schemaID:number):IFlexiSchema
        // {
        //     var rows = this.DB.all.sync(this.DB, `select * from [.schemas] where SchemaID=$SchemaID`, {$SchemaID: schemaID});
        //     return rows[0] as IFlexiSchema;
        // }
        /*
    
         */
        // public generateView(classID:number)
        // {
        //     var classDef = this.getClassDefByID(classID);
        //     var schemaDef = this.getSchemaByID(classDef.BaseSchemaID);
        //     this.applyClassDefinition(classDef, schemaDef);
        // }
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
                self.saveNewClass(self, vars, model);
            }
            this.initExistingColAssignment(vars);
            self.initAndSaveProperties(self, vars);
            // Now vars.newProps are saved and have property IDs assigned
            // Set column assignments
            this.assignColumns(self, vars, COLUMN_ASSIGN_PRIORITY.COL_ASSIGN_REQUIRED);
            this.assignColumns(self, vars, COLUMN_ASSIGN_PRIORITY.COL_ASSIGN_DESIRED);
            // Set class properties
            // ctloMask
            vars.classDef.ctloMask = OBJECT_CONTROL_FLAGS.NONE;
            // Column assignments
            for (var idx = 0; idx < SQLiteDataRefactor.COLUMN_LETTERS.length; idx++) {
                var ch = SQLiteDataRefactor.COLUMN_LETTERS[idx];
                var propID = vars.columnAssignments[ch].propID;
                vars.classDef[ch] = propID;
                if (propID) {
                    var ch_offset = ch.charCodeAt(0) - 'A'.charCodeAt(0);
                    var p = vars.newProps[propID];
                    if (p.Data.unique || (p.Data.role & PROPERTY_ROLE.PROP_ROLE_CODE) || (p.Data.role & PROPERTY_ROLE.PROP_ROLE_ID)) {
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
                        return ca.priority === COLUMN_ASSIGN_PRIORITY.COL_ASSIGN_NOT_SET;
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
                var prior = COLUMN_ASSIGN_PRIORITY.COL_ASSIGN_NOT_SET;
                if (pid) {
                    prior = this.determineColAssignmentPriority(vars.classDef.Data.properties[pid]);
                }
                vars.columnAssignments[c] = { propID: pid, priority: prior };
            }
        };
        /*
    
         */
        SQLiteDataRefactor.prototype.determineColAssignmentPriority = function (cp) {
            var prior = COLUMN_ASSIGN_PRIORITY.COL_ASSIGN_NOT_SET;
            if ((cp.role & PROPERTY_ROLE.PROP_ROLE_ID) || (cp.role & PROPERTY_ROLE.PROP_ROLE_CODE) || cp.unique || cp.indexed)
                prior = COLUMN_ASSIGN_PRIORITY.COL_ASSIGN_REQUIRED;
            else {
                switch (cp.rules.type) {
                    case PROPERTY_TYPE.PROP_TYPE_BINARY:
                    case PROPERTY_TYPE.PROP_TYPE_JSON:
                    case PROPERTY_TYPE.PROP_TYPE_LINK:
                    case PROPERTY_TYPE.PROP_TYPE_OBJECT:
                        prior = COLUMN_ASSIGN_PRIORITY.COL_ASSIGN_NOT_SET;
                        break;
                    default:
                        prior = COLUMN_ASSIGN_PRIORITY.COL_ASSIGN_DESIRED;
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
                    np.ctlv |= VALUE_CONTROL_FLAGS.UNIQUE_INDEX;
                }
                else if (p.indexed) {
                    np.ctlv |= VALUE_CONTROL_FLAGS.INDEX;
                }
                if (p.fastTextSearch) {
                    np.ctlv |= VALUE_CONTROL_FLAGS.FULL_TEXT_INDEX;
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
        SQLiteDataRefactor.COLUMN_LETTERS = 'ABCDEFGHIJ';
        return SQLiteDataRefactor;
    }());
    exports.SQLiteDataRefactor = SQLiteDataRefactor;
});
//# sourceMappingURL=SQLiteDataRefactor.js.map