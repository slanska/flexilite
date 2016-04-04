/**
 * Created by slanska on 2016-01-16.
 */

///<reference path="../../../typings/lib.d.ts"/>
///<reference path="DBInterfaces.d.ts"/>

import sqlite3 = require('sqlite3');
import objectHash = require('object-hash');
import SchemaHelper = require('../../misc/SchemaHelper');

export class SQLiteDataRefactor implements IDBRefactory
{
    constructor(private DB:sqlite3.Database)
    {

    }

    private getClassDefFromRows(rows):IFlexiClass
    {
        var self = this;
        if (rows.length > 0)
        {
            rows[0].Data = JSON.parse(rows[0].Data);
            let result = rows[0] as IFlexiClass;
            result.Properties = self.DB.all.sync(self.DB,
                `select * from [.class_properties] where ClassID = $classID`,
                {$classID: result.ClassID});
            return result;
        }

        return null;
    }

    /*

     */
    getClassDefByName(className:string):IFlexiClass
    {
        var self = this;
        var rows = self.DB.all.sync(self.DB,
            `select * from [.classes] where NameID = (select NameID from [.names] where [Value]= $name) limit 1`,
            {$name: className});
        return self.getClassDefFromRows(rows);
    }

    /*

     */
    getClassDefByID(classID:number):IFlexiClass
    {
        var self = this;
        var rows = self.DB.all.sync(self.DB, `select * from [.classes] where ClassID = $ClassID limit 1`,
            {$ClassID: classID});
        return self.getClassDefFromRows(rows);
    }

    /*

     */
    private getNameByValue(name:string):IFlexiName
    {
        var rows = this.DB.run.sync(this.DB, `insert or ignore into [.names] ([Value]) values ($name);
            select * from [.names] where [Value] = $name limit 1`, {$name: name});
        return rows[0] as IFlexiName;
    }

    /*

     */
    private getNameByID(id:number):IFlexiName
    {
        var rows = this.DB.run.sync(this.DB, `select * from [.names] where [NameID] = id limit 1`, {$id: id});
        if (rows.length > 0)
            return rows[0] as IFlexiName;

        return null;
    }

    private _lastActionReport:string = '';

    getLastActionReport():string
    {
        return this._lastActionReport;
    }

    alterClass(classID:number, newClassDef?:IClassDefinition, newSchemaDef?:ISchemaDefinition, newName?:string)
    {
        var self = this;

        // Check if class exists
        var classDef = self.getClassDefByID(classID);
        if (classDef)
        {

        }
        else throw new Error(`Flexilite.alterClass: class with ID '${classID}' not found`);
    }

    /*

     */
    private applyClassDefinition(classDef:IFlexiClass, schemaDef:IFlexiSchema)
    {
        var self = this;

        // Regenerate view if needed
        // Check if class schema needs synchronization
        if (!classDef.ViewOutdated)
        {
            return;
        }

        var viewName = self.getNameByID(classDef.ClassID).Value;
        var viewSQL = `drop view if exists [${viewName}];
            \ncreate view if not exists ${viewName} as select
            [ObjectID]`;

        // Process properties
        var propIdx = 0;
        _.forEach(classDef.Properties, (p:IFlexiClassProperty, propID:number)=>
        {
            if (propIdx > 0)
                viewSQL += ', ';
            propIdx++;

            let propName = self.getNameByID(p.NameID);
            if (p.ColumnAssigned)
            // This property is stored directly in .objects table
            {
                viewSQL += `o.[${p.ColumnAssigned}] as [${propName}]\n`;
            }
            else
            // This property is stored in Values table. Need to use subquery for access
            {
                viewSQL += `\n(select v.[Value] from [.values] v
                    where v.[ObjectID] = o.[ObjectID]
    and v.[PropIndex] = 0 and v.[PropertyID] = ${p.PropertyID}`;
                if ((p.ctlv & 1) === 1)
                    viewSQL += ` and (v.[ctlv] & 1 = 1)`;
                viewSQL += `) as [${propName}]`;
            }
        });

        // non-schema properties are returned as single JSON
        //if (propIdx > 0)
        //    viewSQL += ', ';
        //
        //viewSQL += ` as [.non-schema-props]`;

        viewSQL += ` from [.objects] o
    where o.[ClassID] = ${classDef.ClassID}`;

        if (classDef.ctloMask !== 0)
            viewSQL += `and ((o.[ctlo] & ${classDef.ctloMask}) = ${classDef.ctloMask})`;

        viewSQL += ';\n';

        // Insert trigger when ObjectID or HostID is null.
        // In this case, recursively call insert statement with newly obtained ObjectID
        viewSQL += self.generateTriggerBegin(viewName, 'insert', 'whenNull',
            'when new.[ObjectID] is null or new.[HostID] is null');

        // Generate new ID
        viewSQL += `insert or replace into [.generators] (name, seq) select '.objects',
                coalesce((select seq from [.generators] where name = '.objects') , 0) + 1 ;`;
        viewSQL += `insert into [${viewName}] ([ObjectID], [HostID]`;

        var cols = '';
        _.forEach(classDef.Properties, (p, propID)=>
        {
            let propName = self.getNameByID(p.NameID).Value;
            viewSQL += `, [${propName}]`;
            cols += `, new.[${propName}]`;
        });

        // HostID is expected to be either (a) ID of another (hosting) object
        // or (b) 0 or null - means that object will be self-hosted
        viewSQL += `) select
            [NextID],
             case
                when new.[HostID] is null or new.[HostID] = 0 then [NextID]
                else new.[HostID]
             end

             ${cols} from
             (SELECT coalesce(new.[ObjectID],
             (select (seq)
          FROM [.generators]
          WHERE name = '.objects' limit 1)) AS [NextID])

             ;\n`;
        viewSQL += `end;\n`;

        // Insert trigger when ObjectID is not null
        viewSQL += self.generateTriggerBegin(viewName, 'insert', 'whenNotNull',
            'when not (new.[ObjectID] is null or new.[HostID] is null)');
        viewSQL += self.generateConstraintsForTrigger(viewName, classDef);

        viewSQL += `insert into [.objects] ([ObjectID], [ClassID], [ctlo]`;
        cols = '';
        for (var propID in classDef.Data.properties)
        {
            var p:IFlexiClassProperty = classDef.Properties[propID];
            let propName = self.getNameByID(p.NameID).Value;

            // if column is assigned
            if (p.ColumnAssigned)
            {
                viewSQL += `, [${p.ColumnAssigned}]`;
                cols += `, new.[${propName}]`;
            }
        }

        viewSQL += `) values (new.HostID << 31 | (new.ObjectID & 2147483647),
             ${classDef.ClassID}, ${classDef.ctloMask}${cols});\n`;

        viewSQL += self.generateInsertValues(classDef.ClassID, classDef);
        viewSQL += 'end;\n';

        // Update trigger
        viewSQL += self.generateTriggerBegin(viewName, 'update');
        viewSQL += self.generateConstraintsForTrigger(viewName, classDef);

        var columns = '';
        _.forEach(classDef.Properties, (p, propID)=>
        {
            // if column is assigned
            if (p.ColumnAssigned)
            {
                let propName = self.getNameByID(p.NameID).Value;
                if (columns !== '')
                    columns += ',';
                columns += `[${p.ColumnAssigned}] = new.[${propName}]`;
            }
        });
        if (columns !== '')
        {
            viewSQL += `update [.objects] set ${columns} where [ObjectID] = new.[ObjectID];\n`;
        }

        viewSQL += self.generateInsertValues(classDef.ClassID, classDef);
        viewSQL += self.generateDeleteNullValues(classDef.Data);
        viewSQL += 'end;\n';

        // Delete trigger
        viewSQL += self.generateTriggerBegin(viewName, 'delete');
        viewSQL += `delete from [.objects] where [ObjectID] = new.[ObjectID] and [CollectionID] = ${classDef.ClassID};\n`;
        viewSQL += 'end;\n';

        console.log(viewSQL);

        // Run view script
        self.DB.exec.sync(self.DB, viewSQL);

    }

    /*

     */
    private generateDeleteNullValues(classDef:IClassDefinition):string
    {
        var result = '';

        // Iterate through all properties
        _.forEach(classDef.properties as any, (p:IClassProperty, propID:number) =>
        {
            //
            //if (!p.ColumnAssigned)
            //{
            //    result += `delete from [.values] where [ObjectID] = (old.ObjectID | (old.HostID << 31)) and [PropertyID] = ${p.PropertyID}
            //    and [PropIndex] = 0 and [ClassID] = ${classDef.ClassID} and new.[${p.PropertyName}] is not null;\n`;
            //}
        });
        return result;
    }

    /*
     Generates beginning of INSTEAD OF trigger for dynamic view
     */
    private generateTriggerBegin(viewName:string, triggerKind:string, triggerSuffix = '', when = ''):string
    {
        return `/* Autogenerated code. Do not edit or delete. ${viewName[0].toUpperCase() + viewName.slice(1)}.${triggerKind} trigger*/\n
            drop trigger if exists [trig_${viewName}_${triggerKind}${triggerSuffix}];
    create trigger if not exists [trig_${viewName}_${triggerKind}${triggerSuffix}] instead of ${triggerKind} on [${viewName}]
    for each row\n
    ${when}
    begin\n`;
    }

    /*
     Generates constraints for INSTEAD OF triggers for dynamic view
     */
    private generateConstraintsForTrigger(className:string, classDef:IFlexiClass):string
    {
        var result = '';
        // Iterate through all properties
        _.forEach(classDef.Data.properties as any, (p:IClassProperty, propID:number)=>
        {
// TODO Get property name by ID
            // Is required/not null?
            if (p.rules.minOccurences > 0)
                result += `when new.[${propID}] is null then '${propID} is required'\n`;

            // Is unique
            // TODO Unique in Class.Property, unique in Property (all classes)
            //         if (p.Unique)
            //             result += `when exists(select 1 from [${collectionName}] v where v.[ObjectID] <> new.[ObjectID]
            // and v.[${propName}] = new.[${propName}]) then '${propName} has to be unique'\n`;

            // Range validation

            // Max length validation
            if ((p.rules.maxLength || 0) !== 0 && (p.rules.maxLength || 0) !== -1)
                result += `when typeof(new.[${propID}]) in ('text', 'blob')
        and len(new.[${propID}] > ${p.rules.maxLength}) then 'Length of ${propID} exceeds max value of ${p.rules.maxLength}'\n`;

            // Regex validation
            // TODO Use extension library for Regex

            // TODO Other validation rules?

        });

        if (result.length > 0)
        {
            result = `select raise_error(ABORT, s.Error) from (select case ${result} else null end as Error) s where s.Error is not null;\n`;
        }
        return result;
    }

    /*

     */
    private generateInsertValues(collectionID:number, classDef:IFlexiClass):string
    {
        var self = this;
        var result = '';

        // Iterate through all properties
        _.forEach(classDef.Properties, (p:IFlexiClassProperty, propID) =>
        {
            let propName = self.getNameByID(p.NameID).Value;

            if (!p.ColumnAssigned)
            {
                result += `insert or replace into [Values] ([ObjectID], [ClassID], [PropertyID], [PropIndex], [ctlv], [Value])
             select (new.ObjectID | (new.HostID << 31)), ${collectionID}, ${p.PropertyID}, 0, ${p.ctlv}, new.[${propName}]
             where new.[${propName}] is not null;\n`;
            }
        });
        return result;
    }


    /*

     */
    createClass(name:string, classDef:IClassDefinition, schemaDef?:ISchemaDefinition)
    {
        var self = this;
        // TODO classDef = self.getClassDefByName(name);
        if (classDef)
        {
            /// TODO
            return;
        }


    }

    dropClass(classID:number)
    {
    }

    plainPropertiesToBoxedObject(classID:number, propIDs:PropertyIDs, newRefProp:IClassProperty, filter:IObjectFilter, targetClassID:number)
    {
    }

    plainPropertiesToLinkedObject(classID:number, propIDs:PropertyIDs, newRefProp:IClassProperty, filter:IObjectFilter, targetClassID:number, updateData:boolean, sourceKeyPropID:PropertyIDs, targetKeyPropID:PropertyIDs)
    {
    }

    boxedObjectToPlainProperties(classID:number, refPropID:number, filter:IObjectFilter, propMap:IPropertyMap)
    {
    }

    linkedObjectToPlainProps(classID:number, refPropID:number, filter:IObjectFilter, propMap:IPropertyMap)
    {
    }

    structuralMerge(sourceClassID:number, sourceFilter:IObjectFilter, sourceKeyPropID:PropertyIDs, targetClassID:number, targetKeyPropID:PropertyIDs, propMap:IPropertyMap)
    {
    }

    structuralSplit(sourceClassID:number, filter:IObjectFilter, targetClassID:number, propMap:IPropertyMap, targetClassDef?:IClassDefinition)
    {
    }

    moveToAnotherClass(sourceClassID:number, filter:IObjectFilter, targetClassID:number, propMap:IPropertyMap)
    {
    }

    removeDuplicatedObjects(classID:number, filter:IObjectFilter, compareFunction:string, keyProps:PropertyIDs, replaceTargetNulls:boolean)
    {
    }

    splitProperty(classID:number, sourcePropID:number, propRules:ISplitPropertyRules)
    {
    }

    mergeProperties(classID:number, sourcePropIDs:number[], targetProp:IClassProperty, expression:string)
    {
    }

    alterClassProperty(classID:number, propertyName:string, propDef:IClassProperty, newPropName?:string)
    {
    }

    createClassProperty(classID:number, propertyName:string, propDef:IClassProperty)
    {
    }

    dropClassProperty(classID:number, propertyName:string)
    {
    }

    private static IsPropertyBoxedObject(p:IClassProperty)
    {
        return p.rules && p.rules.type === PROPERTY_TYPE.OBJECT && p.reference
            && p.reference.type === OBJECT_REFERENCE_TYPE.BOXED_OBJECT;
    }

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
    generateClassAndSchemaDefForSync(model:ISyncOptions):IClassAndSchema
    {
        var self = this;

        // Normalize model
        var converter = new SchemaHelper(self.DB, model);
        converter.getNameID = self.getNameByID.bind(self);
        converter.convertFromNodeOrmSync();
        var schemaData = {} as IFlexiSchema;

        // Load existing class definition if exists
        var classDef = self.getClassDefByName(model.table);
        if (classDef)
        // Class already exists. It would be ALTER CLASS rather than CREATE CLASS
        {
            var classProps = <IFlexiClassProperty[]>self.DB.all.sync(self.DB,
                `select * from [.vw_class_properties] where ClassID = $ClassID;`, {$ClassID: classDef.ClassID});

            var existingProps = {} as IFlexiClassPropDictionary;
            var propsToDelete = [] as IFlexiClassProperty[];
            _.forEach(classProps, (p:IFlexiClassProperty)=>
            {
                if (converter.targetClass.hasOwnProperty(p.Name))
                    existingProps[p.Name] = p;
                else
                    propsToDelete.push(p);
            });

            var newProps = {} as {[propName:string]:IFlexiClassProperty};
            _.forEach(converter.targetClass, (p:IClassProperty, propName:string)=>
            {
                let np = {} as IFlexiClassProperty;
                np.ClassID = classDef.ClassID;
                np.Data = p;
                np.NameID = self.getNameByValue(propName).NameID;
                let ep = existingProps[propName];
                if (ep)
                {
                    np.PropertyID = ep.PropertyID;
                }

                np.ctlv = 0;
                if (p.indexed)
                {
                    np.ctlv |= VALUE_CONTROL_FLAGS.INDEX;
                }

                // TODO set other ctlv flags

                newProps[propName] = np;

                // Process column assignment

            });

            // Fill schema

            // If there are any new OBJECT properties with 'boxed_object', update existing class schemas so that
            // these objects will be accessible from row root
            var replaceSchema = '';
            var newBoxedObjProps = _.forEach(converter.targetClass, (p:IClassProperty, propName:string)=>
            {
                if (SQLiteDataRefactor.IsPropertyBoxedObject(p)
                    && !SQLiteDataRefactor.IsPropertyBoxedObject(existingProps[propName].Data))
                {
                    if (replaceSchema === '')
                        replaceSchema = `json_set([Data] `;
                    let propID = existingProps[propName].PropertyID;
                    replaceSchema += `, json_set(Data, '$.properties.${propID}', 'jsonPath: ${''}')`;
                }
            });

            if (replaceSchema !== '')
            {
                replaceSchema += `)`;
                self.DB.run.sync(self.DB, `update [.schemas] set [Data] = ${replaceSchema} where ClassID = $ClassID`,
                    {$ClassID: classDef.ClassID})
            }

            // Fill updated properties
            var updPropStmt = self.DB.prepare(`insert or replace into [.class_properties] 
                (PropertyID, ClassID, NameID, ColumnAssigned, ctlv, Data) 
                values ($PropertyID, $ClassID, $NameID, $ColumnAssigned, $ctlv, $Data);`);
            //_.forEach()


            var delPropStmt = self.DB.prepare(`delete from [.class_properties] where PropertyID = $propID`);
            // Remove properties that are not in the new structure
            _.forEach(propsToDelete, (p:IFlexiClassProperty, idx)=>
            {
                delPropStmt.run.sync(delPropStmt, {$propID: p.PropertyID});
            });

            //schemaData.Data = converter.targetSchema;
            var existingSchema:IFlexiSchema = null;

            // Check if this schema is already defined.
            // By schema signature
            var hashValue = objectHash(schemaData);

            var schemas = self.DB.all.sync(self.DB, `select * from [.schemas] where Hash = $hash and NameID = $classNameID`,
                {hash: hashValue, NameID: classDef.NameID});
            existingSchema = _.find(schemas, (item:IFlexiSchema)=>
            {
                if (_.isEqual(item.Data, schemaData.Data))
                    return true;
            });
        }

        if (!existingSchema)
        {
            // Schema match not found. Create new one
            let sql = `insert into [.schemas] into (NameID, Data, Hash) values ($NameID, $Data, $Hash);
            select last_insert_rowid();`;
            var rows = self.DB.all.sync(self.DB, sql,
                {
                    $NameID: self.getNameByValue(model.table).NameID,
                    $Data: JSON.stringify(schemaData.Data),
                    $Hash: hashValue
                });
            existingSchema = rows[0] as IFlexiSchema;

        }
        else
        {

        }

        if (classDef)
        {
            //this.alterClass(classDef.ClassID, converter.targetClass, converter.targetSchema);
        }
        else
        {
            //this.createClass(model.table, converter.targetClass, converter.targetSchema);
        }

        return {Class: classDef, Schema: schemaData};
    }


}