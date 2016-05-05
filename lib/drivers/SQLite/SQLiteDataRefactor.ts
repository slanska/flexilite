/**
 * Created by slanska on 2016-01-16.
 */

///<reference path="../../../typings/lib.d.ts"/>
///<reference path="DBInterfaces.d.ts"/>

import sqlite3 = require('sqlite3');
import objectHash = require('object-hash');
import {SchemaHelper, IShemaHelper} from '../../misc/SchemaHelper';
var Sync = require('syncho');
import {ReverseEngine} from '../../misc/reverseEng';
import _ = require('lodash');

export class SQLiteDataRefactor implements IDBRefactory
{
    private static COLUMN_LETTERS = 'ABCDEFGHIJ'; // TODO KLMNOP

    /*

     */
    importFromDatabase(options:IImportDatabaseOptions):void
    {

        var self = this;

        let srcDB = self.DB;
        let srcTbl = options.sourceTable || options.targetTable;
        if (options.sourceConnectionString)
        {
            srcDB = new sqlite3.Database(options.sourceConnectionString, sqlite3.OPEN_READONLY);
            if (_.isEmpty(srcTbl))
                srcTbl = options.targetTable;
        }
        else
        {
            if (srcTbl === options.targetTable)
                throw new Error(`Source and target tables cannot be the same`);
        }

        // load metadata for source table
        let reng = new ReverseEngine(srcDB);
        let srcMeta = reng.loadSchemaFromDatabase();
        let srcTableMeta = srcMeta[srcTbl];

        // Check if target flexitable exists
        let clsDef = self.getClassDefByName(options.targetTable);
        if (!clsDef)
        {
            let schemaHlp = new SchemaHelper(self.DB, srcTableMeta, options.columnNameMap);
            schemaHlp.getNameID = self.getNameID.bind(self);
            schemaHlp.getClassIDbyName = self.getClassIDbyName.bind(self);
            schemaHlp.convertFromNodeOrmSync();
            clsDef = {} as IFlexiClass;
            clsDef.NameID = self.getNameByValue(options.targetTable).NameID;
            clsDef.Data = {properties: schemaHlp.targetClassProps};

            self.createClass(options.targetTable, clsDef.Data);
        }

        let nProcessed = 0;
        let selQry = `select * from [${srcTbl}]`;
        if (!_.isEmpty(options.whereClause))
            selQry += ` where ${options.whereClause}`;
        selQry += `;`;

        let insSQL = '';
        let insSQLValues = '';
        let insStmt = null;
        try
        {
            let runner = function (callback:(error:Error, count:number)=>void)
            {
                self.DB.serialize(()=>
                {
                    let inTrn = false;
                    srcDB.each(selQry,
                        (error, row)=>
                        {
                            if (error)
                            {
                                if (inTrn)
                                {
                                    srcDB.exec(`rollback to savepoint aaa;`);
                                    inTrn = false;
                                }
                                callback(error, nProcessed);
                            }

                            nProcessed++;

                            if (!inTrn)
                            {
                                srcDB.exec(`savepoint aaa;`);
                                inTrn = true;
                            }

                            var newObj = {};

                            if (!insStmt)
                            {
                                insSQL = `insert into [${options.targetTable}] (`;
                                insSQLValues = `) values (`
                            }
                            let fldNo = 0;
                            _.each(row, (fld, fldName:string)=>
                            {
                                if (options.columnNameMap)
                                {
                                    fldName = options.columnNameMap[fldName];
                                    if (_.isEmpty(fldName))
                                        return;
                                }

                                let paramName = `$${++fldNo}`;
                                newObj[paramName] = fld;

                                if (!insStmt)
                                {
                                    if (fldNo > 1)
                                    {
                                        insSQLValues += ', ';
                                        insSQL += `,`;
                                    }
                                    insSQLValues += paramName;
                                    insSQL += `[${fldName}]`;
                                }
                            });

                            if (!insStmt)
                            {
                                insSQL += insSQLValues + ');';
                                insStmt = self.DB.prepare(insSQL);
                            }

                            insStmt.run(newObj);

                            if (nProcessed % 10000 === 0 && inTrn)
                            {
                                srcDB.exec(`release aaa;`);
                                inTrn = false;
                            }
                        },
                        (err, count)=>
                        {
                            insStmt.finalize();
                            if (inTrn)
                            {
                                if (err)
                                    srcDB.exec(`rollback to savepoint aaa;`);
                                else
                                    srcDB.exec(`release aaa;`);
                            }

                            callback(err, count);
                        });
                });
            };

            let rslt = runner.sync(self);
        }
        finally
        {
            console.log(`Done`);
        }
    }

    constructor(private DB:sqlite3.Database)
    {

    }

    /*
     Loads class properties from rows, assuming that rows are loaded from .classes table
     */
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
    getClassIDbyName(className:string):number
    {
        var cls = this.getClassDefByName(className);
        return cls.ClassID;
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
        this.DB.run.sync(this.DB, `insert or ignore into [.names] ([Value]) values ($name);`, {$name: name});
        var rows = this.DB.all.sync(this.DB, `select * from [.names] where [Value] = $name limit 1;`, {$name: name});
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

    /*

     */
    private getNameID(name:string):number
    {
        var nm = this.getNameByValue(name);
        return nm.NameID;
    }

    private _lastActionReport:string = '';

    getLastActionReport():string
    {
        return this._lastActionReport;
    }

    /*
     Alter class definition.
     @newClassDef - can add/remove or change properties
     Note: property renaming is not supported here. alterClassProperty should be used for that.

     */
    alterClass(classID:number, newClassDef?:IClassDefinition, newName?:string)
    {
        var self = this;
        var classChanged = false;

        // Check if class exists
        var classDef = self.getClassDefByID(classID);
        if (classDef)
        {
            if (newClassDef)
            {
                classChanged = true;
            }

            if (!_.isEmpty(newName))
            {
                classDef.Name = newName;
                classChanged = true;
            }

            if (classChanged)
            {
                self.DB.serialize.sync(self.DB, ()=>
                {
                    let newNameId = self.getNameByValue(classDef.Name).NameID;
                    self.DB.run(`update [.classes] set NameID = $NameID where ClassID=$ClassID;`,
                        {$NameID: newNameId, ClassID: classID});
                });
            }
        }
        else throw new Error(`Flexilite.alterClass: class with ID '${classID}' not found`);
    }

    /*

     */
    private applyClassDefinition(classDef:IFlexiClass)
    {
        var self = this;
        // TODO
    }

    // TODO validateClassName

    /*
     Create new Flexilite class using @name and @classDef as class definition
     */
    createClass(name:string, classDef:IClassDefinition)
    {
        var self = this;
        let clsDef = self.getClassDefByName(name);
        if (clsDef)
        {
            self.alterClass(clsDef.ClassID, classDef);
        }
        else
        {
            let jsonClsDef = JSON.stringify(classDef);
            self.DB.exec.sync(self.DB, `create virtual table [${name}] using 'flexi_eav' ('${jsonClsDef}');`);
        }
    }

    /*
     Drops class and all its data
     */
    dropClass(classID:number)
    {
        var self = this;
        var clsDef = self.getClassDefByID(classID);
        self.DB.exec.sync(self.DB, `drop table [${clsDef.Name}]`);
    }

    propertiesToObject(filter:IObjectFilter, propIDs:PropertyIDs, newRefProp:IClassProperty,
                       targetClassID:number, sourceKeyPropID:PropertyIDs,
                       targetKeyPropID:PropertyIDs)
    {
    }

    objectToProperties(classID:number, refPropID:number, filter:IObjectFilter, propMap:IPropertyMap)
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
    generateClassDefForSync(model:ISyncOptions)
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
            SQLiteDataRefactor.saveNewClass(self, vars, model);
        }

        this.initExistingColAssignment(vars);

        self.initAndSaveProperties(self, vars);
        // Now vars.newProps are saved and have property IDs assigned

        // Set column assignments
        this.assignColumns(self, vars, COLUMN_ASSIGN_PRIORITY.COL_ASSIGN_REQUIRED);
        this.assignColumns(self, vars, COLUMN_ASSIGN_PRIORITY.COL_ASSIGN_DESIRED);

        // Set class properties
        // ctloMask
        vars.classDef.ctloMask = OBJECT_CONTROL_FLAGS.CTLO_NONE;

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
                if (p.Data.unique || (p.Data.role & PROPERTY_ROLE.PROP_ROLE_CODE) || (p.Data.role & PROPERTY_ROLE.PROP_ROLE_ID))
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

        self.applyClassDefinition(vars.classDef);
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
                    return ca.priority === COLUMN_ASSIGN_PRIORITY.COL_ASSIGN_NOT_SET;
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
            let prior = COLUMN_ASSIGN_PRIORITY.COL_ASSIGN_NOT_SET;
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
        let prior = COLUMN_ASSIGN_PRIORITY.COL_ASSIGN_NOT_SET;

        if ((cp.role & PROPERTY_ROLE.PROP_ROLE_ID) || (cp.role & PROPERTY_ROLE.PROP_ROLE_CODE) || cp.unique || cp.indexed)
            prior = COLUMN_ASSIGN_PRIORITY.COL_ASSIGN_REQUIRED;
        else
        {
            switch (cp.rules.type)
            {
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
                np.ctlv |= Value_Control_Flags.CTLV_UNIQUE_INDEX;
            }
            else
                if (p.indexed)
                {
                    np.ctlv |= Value_Control_Flags.CTLV_INDEX;
                }

            if (p.fastTextSearch)
            {
                np.ctlv |= Value_Control_Flags.CTLV_FULL_TEXT_INDEX;
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

    /*

     */
    private static saveNewClass(self:SQLiteDataRefactor, vars:ISyncVariables, model:ISyncOptions)
    {
        vars.classDef = {} as IFlexiClass;
        vars.classDef.NameID = self.getNameByValue(model.table).NameID;
        vars.classDef.ctloMask = 0; // TODO

        let clsID = self.DB.all.sync(self.DB, `insert or replace into [.classes] (NameID, BaseSchemaID, ctloMask, A, B, C, D, E, F, G, H, I, J) 
                values ($NameID, $ctloMask, $A, $B, $C, $D, $E, $F, $G, $H, $I, $J); select last_insert_rowid();`, {
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