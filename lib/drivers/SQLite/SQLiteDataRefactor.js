/**
 * Created by slanska on 2016-01-16.
 */
"use strict";
var SQLiteDataRefactor = (function () {
    function SQLiteDataRefactor(DB) {
        this.DB = DB;
    }
    /*
    
     */
    SQLiteDataRefactor.prototype.getClassDefByName = function (className) {
        var self = this;
        var rows = self.DB.all.sync(self.DB, "select * from [.classes] where NameID = (select NameID from [.names] where [Value]= @name) limit 1", { name: className });
        if (rows.length > 0) {
            rows[0].Data = JSON.parse(rows[0].Data);
            return rows[0];
        }
        return null;
    };
    /*

     */
    SQLiteDataRefactor.prototype.getClassDefByID = function (classID) {
        var self = this;
        var rows = self.DB.all.sync(self.DB, "select * from [.classes] where ClassID = @ClassID limit 1", { ClassID: classID });
        if (rows.length > 0) {
            rows[0].Data = JSON.parse(rows[0].Data);
            return rows[0];
        }
        return null;
    };
    SQLiteDataRefactor.prototype.getLastActionReport = function () {
        return null;
    };
    SQLiteDataRefactor.prototype.alterClass = function (classID, newClassDef, newSchemaDef, newName) {
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
        var viewSQL = "drop view if exists " + opts.table + ";\n            \ncreate view if not exists " + opts.table + " as select\n            [ObjectID] >> 31 as HostID,\n    ([ObjectID] & 2147483647) as ObjectID,";
        // Process properties
        var propIdx = 0;
        _.forEach(classDef.Data.properties, function (prop) {
        });
        for (var propName in schemaDef.Data.properties) {
            if (propIdx > 0)
                viewSQL += ', ';
            propIdx++;
            var p = classDef.Data.properties[propName];
            if (p.ColumnAssigned) 
            // This property is stored directly in .objects table
            {
                viewSQL += "o.[" + p.ColumnAssigned + "] as [" + p.PropertyName + "]\n";
            }
            else 
            // This property is stored in Values table. Need to use subquery for access
            {
                viewSQL += "\n(select v.[Value] from [.values] v\n                    where v.[ObjectID] = o.[ObjectID]\n    and v.[PropIndex] = 0 and v.[PropertyID] = " + p.PropertyID;
                if ((p.ctlv & 1) === 1)
                    viewSQL += " and (v.[ctlv] & 1 = 1)";
                viewSQL += ") as [" + p.PropertyName + "]";
            }
        }
        // non-schema properties are returned as single JSON
        //if (propIdx > 0)
        //    viewSQL += ', ';
        //
        //viewSQL += ` as [.non-schema-props]`;
        viewSQL += " from [.objects] o\n    where o.[ClassID] = " + def.Class.ClassID;
        if (classDef.ctloMask !== 0)
            viewSQL += "and ((o.[ctlo] & " + def.Class.ctloMask + ") = " + def.Class.ctloMask + ")";
        viewSQL += ';\n';
        // Insert trigger when ObjectID or HostID is null.
        // In this case, recursively call insert statement with newly obtained ObjectID
        viewSQL += self.generateTriggerBegin(opts.table, 'insert', 'whenNull', 'when new.[ObjectID] is null or new.[HostID] is null');
        // Generate new ID
        viewSQL += "insert or replace into [.generators] (name, seq) select '.objects',\n                coalesce((select seq from [.generators] where name = '.objects') , 0) + 1 ;";
        viewSQL += "insert into [" + opts.table + "] ([ObjectID], [HostID]";
        var cols = '';
        for (var propName in def.Class.Data.properties) {
            var p = def.Class.Data.properties[propName];
            viewSQL += ", [" + p.PropertyName + "]";
            cols += ", new.[" + p.PropertyName + "]";
        }
        // HostID is expected to be either (a) ID of another (hosting) object
        // or (b) 0 or null - means that object will be self-hosted
        viewSQL += ") select\n            [NextID],\n             case\n                when new.[HostID] is null or new.[HostID] = 0 then [NextID]\n                else new.[HostID]\n             end\n\n             " + cols + " from\n             (SELECT coalesce(new.[ObjectID],\n             (select (seq)\n          FROM [.generators]\n          WHERE name = '.objects' limit 1)) AS [NextID])\n\n             ;\n";
        viewSQL += "end;\n";
        // Insert trigger when ObjectID is not null
        viewSQL += self.generateTriggerBegin(opts.table, 'insert', 'whenNotNull', 'when not (new.[ObjectID] is null or new.[HostID] is null)');
        viewSQL += self.generateConstraintsForTrigger(opts.table, def.Class.Data);
        viewSQL += "insert into [.objects] ([ObjectID], [ClassID], [ctlo]";
        cols = '';
        for (var propName in def.Schema.Data.properties) {
            var p = classDef.Data.properties[propName];
            // if column is assigned
            if (p.ColumnAssigned) {
                viewSQL += ", [" + p.ColumnAssigned + "]";
                cols += ", new.[" + p.PropertyName + "]";
            }
        }
        viewSQL += ") values (new.HostID << 31 | (new.ObjectID & 2147483647),\n             " + classDef.ClassID + ", " + classDef.ctloMask + cols + ");\n";
        viewSQL += self.generateInsertValues(classDef.ClassID, def.Class.Data);
        viewSQL += 'end;\n';
        // Update trigger
        viewSQL += self.generateTriggerBegin(opts.table, 'update');
        viewSQL += self.generateConstraintsForTrigger(opts.table, def.Class.Data);
        var columns = '';
        for (var propName in classDef.Data.properties) {
            var p = classDef.Data.properties[propName];
            // if column is assigned
            if (p.ColumnAssigned) {
                if (columns !== '')
                    columns += ',';
                columns += "[" + p.ColumnAssigned + "] = new.[" + p.PropertyName + "]";
            }
        }
        if (columns !== '') {
            viewSQL += "update [.objects] set " + columns + " where [ObjectID] = new.[ObjectID];\n";
        }
        viewSQL += self.generateInsertValues(classDef.ClassID, classDef.Data);
        viewSQL += self.generateDeleteNullValues(classDef.Data);
        viewSQL += 'end;\n';
        // Delete trigger
        viewSQL += self.generateTriggerBegin(opts.table, 'delete');
        viewSQL += "delete from [.objects] where [ObjectID] = new.[ObjectID] and [CollectionID] = " + def.Class.ClassID + ";\n";
        viewSQL += 'end;\n';
        console.log(viewSQL);
        // Run view script
        self.DB.exec.sync(self.DB, viewSQL);
    };
    SQLiteDataRefactor.prototype.createClass = function (name, classDef, schemaDef) {
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
    return SQLiteDataRefactor;
}());
exports.SQLiteDataRefactor = SQLiteDataRefactor;
//# sourceMappingURL=SQLiteDataRefactor.js.map