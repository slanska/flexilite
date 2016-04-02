/**
 * Created by slanska on 2016-01-16.
 */

///<reference path="../../../typings/lib.d.ts"/>

import sqlite3 = require('sqlite3');

export class SQLiteDataRefactor implements IDBRefactory
{
    constructor(private DB:sqlite3.Database)
    {

    }

    /*
    
     */
    getClassDefByName(className:string):IClassDefinition
    {
        var self = this;
        var rows = self.DB.all.sync(self.DB, `select * from [.classes] where NameID = (select NameID from [.names] where [Value]= @name) limit 1`,
            {name: className});
        if (rows.length > 0)
        {
            rows[0].Data = JSON.parse(rows[0].Data);
            return rows[0] as IClassDefinition;
        }

        return null;
    }

    /*

     */
    getClassDefByID(classID:string):IClassDefinition
    {
        var self = this;
        var rows = self.DB.all.sync(self.DB, `select * from [.classes] where ClassID = @ClassID limit 1`,
            {ClassID: classID});
        if (rows.length > 0)
        {
            rows[0].Data = JSON.parse(rows[0].Data);
            return rows[0] as IClassDefinition;
        }

        return null;
    }

    getLastActionReport():string
    {
        return null;
    }

    alterClass(classID:number, newClassDef?:IClassDefinition, newSchemaDef?:ISchemaDefinition, newName?:string)
    {
    }

    /*

     */
    private applyClassDefinition(classDef:IClassDefinition, schemaDef:ISchemaDefinition)
    {
        var self = this;

        // Regenerate view if needed
        // Check if class schema needs synchronization
        if (!classDef.ViewOutdated)
        {
            return;
        }

        var viewSQL = `drop view if exists ${opts.table};
            \ncreate view if not exists ${opts.table} as select
            [ObjectID] >> 31 as HostID,
    ([ObjectID] & 2147483647) as ObjectID,`;
        // Process properties
        var propIdx = 0;
        _.forEach(classDef.Data.properties, (prop:IClassDefinition)=>
        {
        });

        for (var propName in schemaDef.Data.properties)
        {
            if (propIdx > 0)
                viewSQL += ', ';
            propIdx++;
            var p:IClassProperty = classDef.Data.properties[propName];
            if (p.ColumnAssigned)
            // This property is stored directly in .objects table
            {
                viewSQL += `o.[${p.ColumnAssigned}] as [${p.PropertyName}]\n`;
            }
            else
            // This property is stored in Values table. Need to use subquery for access
            {
                viewSQL += `\n(select v.[Value] from [.values] v
                    where v.[ObjectID] = o.[ObjectID]
    and v.[PropIndex] = 0 and v.[PropertyID] = ${p.PropertyID}`;
                if ((p.ctlv & 1) === 1)
                    viewSQL += ` and (v.[ctlv] & 1 = 1)`;
                viewSQL += `) as [${p.PropertyName}]`;
            }
        }

        // non-schema properties are returned as single JSON
        //if (propIdx > 0)
        //    viewSQL += ', ';
        //
        //viewSQL += ` as [.non-schema-props]`;

        viewSQL += ` from [.objects] o
    where o.[ClassID] = ${def.Class.ClassID}`;

        if (classDef.ctloMask !== 0)
            viewSQL += `and ((o.[ctlo] & ${def.Class.ctloMask}) = ${def.Class.ctloMask})`;

        viewSQL += ';\n';

        // Insert trigger when ObjectID or HostID is null.
        // In this case, recursively call insert statement with newly obtained ObjectID
        viewSQL += self.generateTriggerBegin(opts.table, 'insert', 'whenNull',
            'when new.[ObjectID] is null or new.[HostID] is null');

        // Generate new ID
        viewSQL += `insert or replace into [.generators] (name, seq) select '.objects',
                coalesce((select seq from [.generators] where name = '.objects') , 0) + 1 ;`;
        viewSQL += `insert into [${opts.table}] ([ObjectID], [HostID]`;

        var cols = '';
        for (var propName in def.Class.Data.properties)
        {
            var p:IClassProperty = def.Class.Data.properties[propName];
            viewSQL += `, [${p.PropertyName}]`;
            cols += `, new.[${p.PropertyName}]`;
        }

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
        viewSQL += self.generateTriggerBegin(opts.table, 'insert', 'whenNotNull',
            'when not (new.[ObjectID] is null or new.[HostID] is null)');
        viewSQL += self.generateConstraintsForTrigger(opts.table, def.Class.Data);

        viewSQL += `insert into [.objects] ([ObjectID], [ClassID], [ctlo]`;
        cols = '';
        for (var propName in def.Schema.Data.properties)
        {
            var p:IClassProperty = classDef.Data.properties[propName];

            // if column is assigned
            if (p.ColumnAssigned)
            {
                viewSQL += `, [${p.ColumnAssigned}]`;
                cols += `, new.[${p.PropertyName}]`;
            }
        }

        viewSQL += `) values (new.HostID << 31 | (new.ObjectID & 2147483647),
             ${classDef.ClassID}, ${classDef.ctloMask}${cols});\n`;

        viewSQL += self.generateInsertValues(classDef.ClassID, def.Class.Data);
        viewSQL += 'end;\n';

        // Update trigger
        viewSQL += self.generateTriggerBegin(opts.table, 'update');
        viewSQL += self.generateConstraintsForTrigger(opts.table, def.Class.Data);

        var columns = '';
        for (var propName in classDef.Data.properties)
        {
            var p:IClassProperty = classDef.Data.properties[propName];

            // if column is assigned
            if (p.ColumnAssigned)
            {
                if (columns !== '')
                    columns += ',';
                columns += `[${p.ColumnAssigned}] = new.[${p.PropertyName}]`;
            }
        }
        if (columns !== '')
        {
            viewSQL += `update [.objects] set ${columns} where [ObjectID] = new.[ObjectID];\n`;
        }

        viewSQL += self.generateInsertValues(classDef.ClassID, classDef.Data);
        viewSQL += self.generateDeleteNullValues(classDef.Data);
        viewSQL += 'end;\n';

        // Delete trigger
        viewSQL += self.generateTriggerBegin(opts.table, 'delete');
        viewSQL += `delete from [.objects] where [ObjectID] = new.[ObjectID] and [CollectionID] = ${def.Class.ClassID};\n`;
        viewSQL += 'end;\n';

        console.log(viewSQL);

        // Run view script
        self.DB.exec.sync(self.DB, viewSQL);

    }

    createClass(name:string, classDef:IClassDefinition, schemaDef?:ISchemaDefinition)
    {

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


}