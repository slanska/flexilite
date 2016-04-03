/**
 * Created by slanska on 2016-01-16.
 */
(function (factory) {
    if (typeof module === 'object' && typeof module.exports === 'object') {
        var v = factory(require, exports); if (v !== undefined) module.exports = v;
    }
    else if (typeof define === 'function' && define.amd) {
        define(["require", "exports", 'object-hash', '../../misc/SchemaHelper'], factory);
    }
})(function (require, exports) {
    "use strict";
    var objectHash = require('object-hash');
    var SchemaHelper = require('../../misc/SchemaHelper');
    var SQLiteDataRefactor = (function () {
        function SQLiteDataRefactor(DB) {
            this.DB = DB;
            this._lastActionReport = '';
        }
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
            else {
            }
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
            for (var propName in classDef.properties) {
                var p = classDef.properties[propName];
            }
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
        SQLiteDataRefactor.prototype.generateClassAndSchemaDefForSync = function (model) {
            var self = this;
            // TODO
            // Normalize model
            var converter = new SchemaHelper(self.DB, model);
            converter.getNameID = self.getNameByID.bind(self);
            converter.convert();
            var schemaData = {};
            schemaData.Data = converter.targetSchema;
            var existingSchema = null;
            var classDef = self.getClassDefByName(model.table);
            if (classDef) 
            // Class already exists. It would be ALTER CLASS rather than CREATE CLASS
            {
                // Check if this schema is already defined.
                // By schema signature
                var hashValue = objectHash(schemaData);
                var schemas = self.DB.all.sync(self.DB, "select * from [.schemas] where Hash = $hash and NameID = $classNameID", { hash: hashValue, NameID: classDef.NameID });
                existingSchema = _.find(schemas, function (item) {
                    if (_.isEqual(item.Data, schemaData.Data))
                        return true;
                });
            }
            if (!existingSchema) {
                // Schema match not found. Create new one
                var sql_1 = "insert into [.schemas] into (NameID, Data, Hash) values ($NameID, $Data, $Hash);\n            select last_insert_rowid();";
                var rows = self.DB.all.sync(self.DB, sql_1, {
                    $NameID: self.getNameByValue(model.table).NameID,
                    $Data: JSON.stringify(schemaData.Data),
                    $Hash: hashValue
                });
                existingSchema = rows[0];
            }
            else {
            }
            var sql = "insert or replace [.classes] (NameID, ctlo, Data) values ();";
            //
            //    // Load existing model, if it exists
            //    var classDef = this.getClassDefByName(model.table);
            //
            //    // Assume all existing properties as candidates for removal
            //    var deletedProperties:number[] = [];
            //    _.forEach(classDef.Data.properties, (prop, propID)=>
            //    {
            //        deletedProperties.push(propID);
            //    });
            //
            //    var insCStmt = self.DB.prepare(
            //        `insert or ignore into [.classes] ([ClassName], [DefaultScalarType], [ClassID])
            //        select ?, ?, (select ClassID from [.classes] where ClassName = ? limit 1);`);
            //
            //    var insCPStmt = null;
            //
            //    function saveClassProperty(cp:IClassProperty)
            //    {
            //        if (!insCPStmt || insCPStmt === null)
            //        {
            //            insCPStmt = self.DB.prepare(`insert or replace into [.class_properties]
            //            ([ClassID], [PropertyID],
            // [PropertyName], [TrackChanges], [DefaultValue], [DefaultDataType],
            // [MinOccurences], [MaxOccurences], [Unique], [MaxLength], [ReferencedClassID],
            // [ReversePropertyID], [ColumnAssigned]) values (?,
            // (select [ClassID] from [.classes] where [ClassName] = ? limit 1),
            //  ?, ?, ?, ?,
            //  ?, ?, ?, ?, ?, ?, ?);`);
            //        }
            //
            //        insCPStmt.run.sync(insCPStmt, [
            //            classDef.ClassID,
            //            propName,
            //            cp.PropertyName,
            //            cp.TrackChanges,
            //            cp.DefaultValue,
            //            cp.DefaultDataType,
            //            cp.MinOccurences,
            //            cp.MaxOccurences,
            //            cp.Unique,
            //            cp.MaxLength,
            //            cp.ReferencedClassID,
            //            cp.ReversePropertyID,
            //            null
            //        ]);
            //    }
            //
            //    // Check properties
            //    for (var propName in model.allProperties)
            //    {
            //        var pd:IORMPropertyDef = model.allProperties[propName];
            //
            //        // Unmark property from removal candidates list
            //        _.remove(deletedProperties, (value)=> value == propName);
            //
            //        var cp:IClassProperty = schemaData.properties[propName.toLowerCase()];
            //        if (!cp)
            //        {
            //            schemaData.properties[propName.toLowerCase()] = cp = {};
            //        }
            //
            //        // Depending on klass, treat properties differently
            //        // Possible values: primary, hasOne, hasMany
            //        switch (pd.klass)
            //        {
            //            case 'primary':
            //                cp.DefaultDataType = pd.type || cp.DefaultDataType;
            //                cp.Indexed = pd.indexed || cp.Indexed;
            //                cp.PropertyName = propName;
            //                cp.Unique = pd.unique || cp.Unique;
            //                cp.DefaultValue = pd.defaultValue || cp.DefaultValue;
            //                var ext = pd.ext || {} as ISchemaPropertyDefinition;
            //
            //                // TODO cp.ColumnAssigned = ext. || cp.ColumnAssigned;
            //                cp.MaxLength = ext.rules.maxLength || cp.MaxLength;
            //                cp.MaxOccurences = ext.rules.maxOccurences || cp.MaxOccurences;
            //                cp.MinOccurences = ext.rules.minOccurences || cp.MinOccurences;
            //                cp.ValidationRegex = ext.rules.regex || cp.ValidationRegex;
            //
            //                insCStmt.run.sync(insCStmt, [propName, cp.DefaultDataType, propName]);
            //
            //                if (pd.type === 'object')
            //                {
            //                    var refModel:ISyncOptions;
            //
            //                    var refClass = this.registerCollectionByObject(propName, null, true);
            //                    cp.ReferencedClassID = refClass.ClassID;
            //                }
            //                else
            //                {
            //
            //                }
            //
            //
            //                break;
            //
            //            case 'hasOne':
            //                var refOneProp = <IHasOneAssociation>_.find(model.one_associations, function (item:IHasOneAssociation, idx, arr)
            //                {
            //                    return (item.field.hasOwnProperty(propName));
            //                });
            //                if (refOneProp)
            //                {
            //                    var refClass = this.getClassDefByName(refOneProp.model.table, true, true);
            //                    cp.ReferencedClassID = refClass.ClassID;
            //
            //                    // FIXME create reverse property & set it as ReversePropertyID
            //                    //cp.ReversePropertyID =
            //
            //                    cp.MinOccurences = refOneProp.required ? 1 : 0;
            //                    cp.MaxOccurences = 1;
            //                }
            //                else
            //                {
            //                    throw '';
            //                }
            //                break;
            //
            //            case 'hasMany':
            //                var refManyProp = <IHasManyAssociation>_.find(model.many_associations, function (item:IHasManyAssociation, idx, arr)
            //                {
            //                    return (item.field.hasOwnProperty(propName));
            //                });
            //
            //                if (refManyProp)
            //                {
            //                }
            //                else
            //                {
            //                    throw '';
            //                }
            //                break;
            //        }
            //
            //        saveClassProperty(cp);
            //
            //    }
            //
            //    for (var oneRel in model.one_associations)
            //    {
            //        var assoc:IHasOneAssociation = model.one_associations[oneRel];
            //        var cp:IClassProperty = schemaData.properties[oneRel.toLowerCase()];
            //        if (!cp)
            //        {
            //            schemaData.properties[oneRel.toLowerCase()] = cp = {};
            //            cp.PropertyName = oneRel;
            //        }
            //        cp.indexed = true;
            //        cp.rules.minOccurences = assoc.required ? 1 : 0;
            //        cp.rules.maxOccurences = 1;
            //        var refClass = self.getClassDefByName(assoc.model.table, true, true);
            //        cp.ReferencedClassID = refClass.ClassID;
            //
            //        // Set reverse property
            //
            //        saveClassProperty(cp);
            //    }
            //
            //    for (var manyRel in model.many_associations)
            //    {
            //        var assoc:IHasOneAssociation = model.one_associations[manyRel];
            //        var cp:IClassProperty = schemaData.properties[manyRel.toLowerCase()];
            //        if (!cp)
            //        {
            //            schemaData.properties[manyRel.toLowerCase()] = cp = {} as IClassProperty;
            //            cp.PropertyName = manyRel;
            //        }
            //        cp.indexed = true;
            //        cp.rules.minOccurences = assoc.required ? 1 : 0;
            //        cp.rules.maxOccurences = 1 << 31;
            //        var refClass = self.getClassDefByName(assoc.model.table, true, true);
            //        cp.ReferencedClassID = refClass.ClassID;
            //
            //        // Set reverse property
            //
            //        saveClassProperty(cp);
            //    }
            //
            //    classDef = this.getClassDefByName(model.table, false, true);
            // TODO
            return { Class: classDef, Schema: schemaData };
        };
        return SQLiteDataRefactor;
    }());
    exports.SQLiteDataRefactor = SQLiteDataRefactor;
});
//# sourceMappingURL=SQLiteDataRefactor.js.map