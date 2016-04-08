/**
 * Created by slanska on 2016-01-16.
 */

///<reference path="../../../typings/lib.d.ts"/>
///<reference path="DBInterfaces.d.ts"/>

import sqlite3 = require('sqlite3');
import objectHash = require('object-hash');
import {SchemaHelper, IShemaHelper} from '../../misc/SchemaHelper';

/*
 Level of priority for property to have fixed column assigned
 */
const enum COLUMN_ASSIGN_PRIORITY
{
    /*
     for indexed and ID/Code properties
     */
    REQUIRED = 2,

    /*
     For scalar properties
     */
    DESIRED = 1,

    /*
     Assignment is not set or not required
     */
    NOT_SET = 0
}

export class SQLiteDataRefactor implements IDBRefactory
{
    static COLUMN_LETTERS = 'ABCDEFGHIJ';

    boxedObjectToLinkedObject(classID:number, refPropID:number)
    {
    }

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
        if (viewName[0] === '.')
            throw new Error(`Invalid class name ${viewName}. Class name may not start from dot ('.')`);

        var viewSQL = `drop view if exists [${viewName}];
            \ncreate view if not exists ${viewName} as select
            [ObjectID]`;

        // Init column assignment map
        let colMap = {} as{[propID:number]:string};
        for (let idx = 0; idx < SQLiteDataRefactor.COLUMN_LETTERS.length; idx++)
        {
            let ch = SQLiteDataRefactor.COLUMN_LETTERS[idx];
            let propID = classDef[ch];
            if (propID)
            {
                colMap[propID] = ch;
            }
        }

        // Process properties
        var propIdx = 0;
        _.forEach(classDef.Properties, (p:IFlexiClassProperty, propID:number)=>
        {
            if (propIdx > 0)
                viewSQL += ', ';
            propIdx++;

            let propName = self.getNameByID(p.NameID).Value;

            let colLetter = colMap[p.PropertyID];
            if (colLetter)
            // This property is stored directly in .objects table in A..J columns
            {
                viewSQL += `o.[${colLetter}] as [${propName}]\n`;
            }
            else
            {
                viewSQL += `flexi_get(${p.PropertyID}, o.[ObjectID], s.[Data], o.[Data]`;
                if (p.Data.defaultValue)
                {
                    if (_.isString(p.Data.defaultValue))
                        viewSQL += `'${p.Data.defaultValue}'`;
                    else viewSQL += `${p.Data.defaultValue}`;
                }
                viewSQL += `) as [${propName}]\n`;
            }
        });

        viewSQL += `, o.[Data] as [.json-data] from [.objects] o join [.schemas] s on o.SchemaID = s.SchemaID
    where o.[ClassID] = ${classDef.ClassID}`;

        if (classDef.ctloMask !== 0)
            viewSQL += `and ((o.[ctlo] & ${classDef.ctloMask}) = ${classDef.ctloMask})`;

        viewSQL += ';\n';

        // Insert trigger when ObjectID is null.
        // In this case, recursively call insert statement with newly obtained ObjectID
        viewSQL += self.generateTriggerBegin(viewName, 'insert', 'whenNull',
            'when new.[ObjectID] is null ');

        // Generate new ID
        viewSQL += `insert or replace into [sqlite_sequence] (name, seq) select '.objects',
                coalesce((select seq from [sqlite_sequence] where name = '.objects'), 0) + 1;`;
        viewSQL += `insert into [${viewName}] ([ObjectID]`;

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
             ${cols} from
             (SELECT coalesce(new.[ObjectID],
             (select (seq)
          FROM [sqlite_sequence]
          WHERE name = '.objects' limit 1)) AS [NextID])
             ;\n`;
        viewSQL += `end;\n`;

        // Insert trigger when ObjectID is not null
        viewSQL += self.generateTriggerBegin(viewName, 'insert', 'whenNotNull',
            'when new.[ObjectID] is not null');
        viewSQL += self.generateConstraintsForTrigger(viewName, classDef);

        viewSQL += `insert into [.objects] ([ObjectID], [ClassID], [ctlo], [Data]`;
        cols = '';
        let jsonData = `json_set({}`;
        for (var propID in classDef.Data.properties)
        {
            var p:IFlexiClassProperty = classDef.Properties[propID];
            let propName = self.getNameByID(p.NameID).Value;

            let colLetter = colMap[p.PropertyID];
            // if column is assigned
            if (colLetter)
            {
                viewSQL += `, [${colLetter}]`;
                cols += `, flexi_json_value(new.[${propName}])`;
            }
            else
            {
                let jsp = schemaDef.Data.properties[propID].map.jsonPath;
                jsonData += `, '$${jsp}', new.[${propName}]`;
            }
        }

        viewSQL += `) values (new.ObjectID,
             ${classDef.ClassID}, ${classDef.ctloMask}${cols},
             ${jsonData}));\n`;

        viewSQL += self.generateInsertValues(classDef.ClassID, classDef);
        viewSQL += 'end;\n';

        // Update trigger
        viewSQL += self.generateTriggerBegin(viewName, 'update');
        viewSQL += self.generateConstraintsForTrigger(viewName, classDef);

        var columns = '';
        _.forEach(classDef.Properties, (p, propID)=>
        {
            let colLetter = colMap[p.PropertyID];
            // if column is assigned
            if (colLetter)
            {
                let propName = self.getNameByID(p.NameID).Value;
                if (columns !== '')
                    columns += ',';
                columns += `[${colLetter}] = new.[${propName}]`;
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
    private generateInsertValues(classID:number, classDef:IFlexiClass):string
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
             select (new.ObjectID, ${classID}, ${p.PropertyID}, 0, ${p.ctlv}, new.[${propName}]
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

    private getSchemaByID(schemaID:number):IFlexiSchema
    {
        var rows = this.DB.all.sync(this.DB, `select * from [.schemas] where SchemaID=$SchemaID`, {$SchemaID: schemaID});
        return rows[0] as IFlexiSchema;
    }

    /*

     */
    public generateView(classID:number)
    {
        var classDef = this.getClassDefByID(classID);
        var schemaDef = this.getSchemaByID(classDef.BaseSchemaID);
        this.applyClassDefinition(classDef, schemaDef);
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
    // TODO Callback, Sync version
    generateClassAndSchemaDefForSync(model:ISyncOptions)
    {
        var self = this;

        // TODO SQLite checkpoint

        var vars = {} as ISyncVariables;
        vars.DB = self.DB;

        // Get mapping schema and class properties.
        // They come as Dictionary of IClassProperty by property name and
        // Dictionary of schema property def by property name
        // Need to transform them before saving to dictionaries by property ID
        vars.converter = new SchemaHelper(self.DB, model);
        vars.converter.getNameID = self.getNameByID.bind(self);
        vars.converter.getClassIDbyName = (name:string)=>
        {
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
        vars.existingProps = {} as IFlexiClassPropDictionaryByID; // Dictionary by property name
        vars.propsToDelete = [] as IFlexiClassProperty[]; // Array of properties
        vars.schemaData = {Data: {properties: {}}} as IFlexiSchema; // future Schema.Data
        vars.newProps = {} as IFlexiClassPropDictionaryByName; // Dictionary by property name
        vars.columnAssignments = {};

        // Init items for [.class_properties]
        _.forEach(vars.converter.targetClassProps, (p:IClassProperty, n:string)=>
        {
            let nameID = self.getNameByValue(n).NameID;
            let np = {} as IFlexiClassProperty;
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
        this.assignColumns(self, vars, COLUMN_ASSIGN_PRIORITY.REQUIRED);
        this.assignColumns(self, vars, COLUMN_ASSIGN_PRIORITY.DESIRED);

        // Set class properties
        // ctloMask
        vars.classDef.ctloMask = OBJECT_CONTROL_FLAGS.NONE;

        // Column assignments
        for (let idx = 0; idx < SQLiteDataRefactor.COLUMN_LETTERS.length; idx++)
        {
            let ch = SQLiteDataRefactor.COLUMN_LETTERS[idx];
            let propID = vars.columnAssignments[ch].propID;
            vars.classDef[ch] = propID;
            if (propID)
            {
                let ch_offset = ch.charCodeAt(0) - 'A'.charCodeAt(0);
                let p:IFlexiClassProperty = vars.newProps[propID];
                if (p.Data.unique || (p.Data.role & PROPERTY_ROLE.Code) || (p.Data.role & PROPERTY_ROLE.ID))
                {
                    vars.classDef.ctloMask |= 1 << (1 + ch_offset);
                }
                else
                    if (p.Data.indexed)
                    {
                        vars.classDef.ctloMask |= 1 << (13 + ch_offset);
                    }
                    else
                        if (p.Data.fastTextSearch)
                        {
                            vars.classDef.ctloMask |= 1 << (25 + ch_offset);
                        }
                // TODO range index is not supported yet
            }
        }

        // Check if there are properties that have changed from OBJECT to LINK
// TODO

        self.initSchemaData(self, vars, model);
        self.prepareSchemaData(self, vars);
        self.saveSchema(self, vars, classNameID);

        self.applyClassDefinition(vars.classDef, vars.schemaData);
    }

    /*

     */
    private assignColumns(self:SQLiteDataRefactor, vars:ISyncVariables, target_priority:COLUMN_ASSIGN_PRIORITY)
    {
        _.forEach(vars.newProps as any, (p:IFlexiClassProperty, id:number)=>
        {
            let prop_priority = self.determineColAssignmentPriority(p.Data);
            if (prop_priority === target_priority)
            {
                // Find unused columns first
                let ca = _.find(vars.columnAssignments, (ca:IColumnAssignmentInfo) =>
                {
                    return ca.priority === COLUMN_ASSIGN_PRIORITY.NOT_SET;
                });
                if (ca)
                {
                    ca.propID = id;
                    return;
                }

                // Find already assigned columns, but associated with lower-priority properties
                ca = _.find(vars.columnAssignments, (ca:IColumnAssignmentInfo) =>
                {
                    return ca.priority < target_priority;
                });
                if (ca)
                {
                    ca.propID = id;
                    return;
                }
            }
        });
    }

    /*

     */
    private initExistingColAssignment(vars:ISyncVariables)
    {
        // Set column assignment
        for (var c = 0; c < SQLiteDataRefactor.COLUMN_LETTERS.length; c++)
        {
            let pid = vars.classDef[SQLiteDataRefactor.COLUMN_LETTERS[c]];
            let prior = COLUMN_ASSIGN_PRIORITY.NOT_SET;
            if (pid)
            {
                prior = this.determineColAssignmentPriority(vars.classDef.Data.properties[pid]);
            }
            vars.columnAssignments[c] = {propID: pid, priority: prior};
        }
    }


    /*

     */
    private determineColAssignmentPriority(cp:IClassProperty)
    {
        let prior = COLUMN_ASSIGN_PRIORITY.NOT_SET;

        if ((cp.role & PROPERTY_ROLE.ID) || (cp.role & PROPERTY_ROLE.Code) || cp.unique || cp.indexed)
            prior = COLUMN_ASSIGN_PRIORITY.REQUIRED;
        else
        {
            switch (cp.rules.type)
            {
                case PROPERTY_TYPE.BINARY:
                case PROPERTY_TYPE.JSON:
                case PROPERTY_TYPE.LINK:
                case PROPERTY_TYPE.OBJECT:
                    prior = COLUMN_ASSIGN_PRIORITY.NOT_SET;
                    break;
                default:
                    prior = COLUMN_ASSIGN_PRIORITY.DESIRED;
            }
        }
        return prior;
    }

    private initSchemaData(self:SQLiteDataRefactor, vars:ISyncVariables, model:ISyncOptions)
    {
        if (!vars.schemaData)
        {
            // Schema match not found. Create new one
            let sql = `insert into [.schemas] into (NameID, Data, Hash) values ($NameID, $Data, $Hash);
            select last_insert_rowid();`;
            var rows = self.DB.all.sync(self.DB, sql,
                {
                    $NameID: self.getNameByValue(model.table).NameID,
                    $Data: JSON.stringify(vars.schemaData.Data),
                    $Hash: objectHash(vars.schemaData.Data)
                });
            vars.schemaData = rows[0] as IFlexiSchema;
        }
        else
        {

        }
    }

    private initAndSaveProperties(self:SQLiteDataRefactor, vars:ISyncVariables)
    {
        // Fill updated properties
        var updPropStmt = self.DB.prepare(`insert or replace into [.class_properties] 
                (PropertyID, ClassID, NameID, ctlv) 
                values ($PropertyID, $ClassID, $NameID, $ctlv);`);

        // Initialize properties
        _.forEach(vars.converter.targetClassProps, (p:IClassProperty, propName:string)=>
        {
            let np = {} as IFlexiClassProperty;
            np.ClassID = vars.classDef.ClassID;
            np.NameID = self.getNameByValue(propName).NameID;
            np.ctlv = 0;
            if (p.unique)
            {
                np.ctlv |= VALUE_CONTROL_FLAGS.UNIQUE_INDEX;
            }
            else
                if (p.indexed)
                {
                    np.ctlv |= VALUE_CONTROL_FLAGS.INDEX;
                }

            if (p.fastTextSearch)
            {
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
    }

    private saveNewClass(self:SQLiteDataRefactor, vars:ISyncVariables, model:ISyncOptions)
    {
        vars.classDef = {} as IFlexiClass;
        vars.classDef.NameID = self.getNameByValue(model.table).NameID;
        // Skip BaseSchemaID now - will set it later
        vars.classDef.ctloMask = 0; // TODO
        // TODO set later: vars.classDef.Data = {properties: vars.newProps};
        //vars.classDef.Hash = objectHash(vars.classDef.Data);

        let clsID = self.DB.all.sync(self.DB, `insert or replace into [.classes] (NameID, BaseSchemaID, ctloMask, A, B, C, D, E, F, G, H, I, J) 
                values ($NameID, $BaseSchemaID, $ctloMask, $A, $B, $C, $D, $E, $F, $G, $H, $I, $J); select last_insert_rowid();`, {
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
    }

    private saveSchema(self:SQLiteDataRefactor, vars:ISyncVariables, classNameID:number)
    {
        self.DB.run.sync(self.DB, `insert or replace into [.schemas] (SchemaID, NameID, Hash, Data) 
                values ($SchemaID, $NameID, $Hash, $Data);`, {
            $SchemaID: vars.schemaData.SchemaID,
            $NameID: classNameID,
            $Hash: objectHash(vars.schemaData.Data),
            $Data: JSON.stringify(vars.schemaData.Data)
        });
    }

    /*
     Initializes vars with data from existing class
     */
    private initWhenClassExists(self:SQLiteDataRefactor, vars:ISyncVariables)
    {
        // Load .class_properties
        var classProps = <IFlexiClassProperty[]>self.DB.all.sync(self.DB,
            `select * from [.vw_class_properties] where ClassID = $ClassID;`, {$ClassID: vars.classDef.ClassID});

        // Add property to either existing list or to candidates for removal
        _.forEach(classProps, (p:IFlexiClassProperty)=>
        {
            if (vars.converter.targetClassProps[p.Name])
                vars.existingProps[p.PropertyID] = p;
            else
                vars.propsToDelete.push(p);
        });

        // Set IDs for existing properties
        _.forEach(vars.newProps as any, (np:IFlexiClassProperty, id:number)=>
        {
            let ep = vars.existingProps[np.NameID];
            if (ep)
            {
                np.PropertyID = ep.PropertyID;
            }
        });

        var delPropStmt = self.DB.prepare(`delete from [.class_properties] where PropertyID = $propID`);
        // Remove properties that are not in the new structure
        _.forEach(vars.propsToDelete, (p:IFlexiClassProperty, idx)=>
        {
            delPropStmt.run.sync(delPropStmt, {$propID: p.PropertyID});
        });
    }

    /*
     Converts schema data from Dictionary<name:string> to Dictionary<nameID>
     */
    private prepareSchemaData(self:SQLiteDataRefactor, vars:ISyncVariables)
    {
        _.forEach(vars.converter.targetSchema, (p:ISchemaPropertyDefinition, n:string)=>
        {
            let nameID = self.getNameByValue(n).NameID;
            vars.schemaData.Data.properties[nameID] = p;
        });

        // Check if this schema is already defined.
        // By schema signature
        var hashValue = objectHash(vars.schemaData);

        var schemas = self.DB.all.sync(self.DB, `select * from [.schemas] where Hash = $hash and NameID = $classNameID`,
            {hash: hashValue, NameID: vars.classDef.NameID});
        let foundSchema = _.find(schemas, (item:IFlexiSchema)=>
        {
            if (_.isEqual(item.Data, vars.schemaData.Data))
            {
                vars.schemaData = item;
                return true;
            }
        });
    }
}

type IColumnAssignmentInfo = {propID?:number, priority:COLUMN_ASSIGN_PRIORITY};

/*
 Internally used set of parameters for synchronization
 Grouped together for easy passing between functions
 */
interface ISyncVariables
{
    /*
     Loaded existing properties. Dictionary by property ID
     */
    existingProps:IFlexiClassPropDictionaryByID;

    /*
     Array of properties to delete
     */
    propsToDelete:IFlexiClassProperty[]; // Array of properties

    /*
     [.schemas] row.
     */
    schemaData:IFlexiSchema;

    /*
     Properties to be inserted/updated. Dictionary by property name
     */
    newProps:IFlexiClassPropDictionaryByID;

    /*

     */
    columnAssignments:{[col:string]:IColumnAssignmentInfo};

    /*

     */
    classDef:IFlexiClass;

    /*

     */
    converter:IShemaHelper;

    /*

     */
    DB:sqlite3.Database;
}