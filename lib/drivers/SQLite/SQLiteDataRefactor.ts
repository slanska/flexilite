/**
 * Created by slanska on 2016-01-16.
 */

///<reference path="../../../typings/lib.d.ts"/>
///<reference path="DBInterfaces.d.ts"/>

import sqlite3 = require('sqlite3');
import objectHash = require('object-hash');
import {SchemaHelper, IShemaHelper} from '../../misc/SchemaHelper';
// var Sync = require('syncho');
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

    private _lastActionReport:ILastActionReport = [];

    getLastActionReport():ILastActionReport
    {
        return this._lastActionReport;
    }

    /*
     Alter class definition.
     @newClassDef - can add/remove or change properties
     Note: property renaming is not supported here. alterClassProperty should be used for that.

     */
    alterClass(className:string, newClassDef?:IClassDefinition, newName?:string)
    {
        var self = this;
        var classChanged = false;

        // Check if class exists
        var classDef = self.getClassDefByName(className);
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
                        {$NameID: newNameId, ClassID: classDef.ClassID});
                });
            }
        }
        else throw new Error(`Flexilite.alterClass: class '${className}' not found`);
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
            self.alterClass(name, classDef);
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

    /*
     Converts set of properties into new object
     */
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

    /*

     */
    removeDuplicatedObjects(classID:number, filter:IObjectFilter, compareFunction:string, keyProps:PropertyIDs, replaceTargetNulls:boolean)
    {
    }

    splitProperty(classID:number, sourcePropID:number, propRules:ISplitPropertyRules)
    {
    }

    mergeProperties(classID:number, sourcePropIDs:number[], targetProp:IClassProperty, expression:string)
    {
    }

    /*
     Returns class property definition by property ID
     */
    private getClassPropertyByID(propID:number):IFlexiClassProperty
    {
        var self = this;
        var rows = self.DB.all.sync(self.DB, `select * from [.class_properties] where PropertyID = $PropertyID limit 1;`,
            {$PropertyID: propID});
        return rows.length === 1 ? rows[0] as IFlexiClassProperty : null;
    }

    /*
     Returns class property definition by class ID and property name
     */
    private getClassProperty(classID:number, propertyName:string):IFlexiClassProperty
    {
        var self = this;
        var rows = self.DB.all.sync(self.DB, `select * from [.class_properties] where ClassID = $ClassID 
        and NameID = (select NameID from [.names] where Value = $PropName) limit 1;`,
            {$ClassID: classID, $PropName: propertyName});
        return rows.length === 1 ? rows[0] as IFlexiClassProperty : null;
    }

    /*
     Validates property alteration
     */
    checkAlterClassProperty(className:string, propertyName:string, propDef:IClassProperty, newPropName?:string,
                            limit?:number)
    {

    }

    /*
     Initializes 'reference' attribute of property definition. Returns referenced class definition
     */
    private initPropReference(clsDef:IFlexiClass, propertyName:string, propDef:IClassProperty):IFlexiClass
    {
        var self = this;
        if (!propDef.reference)
        {
            throw new Error(`Reference definition is missing in ${clsDef.Name}.${propertyName}`);
        }

        let refClsDef:IFlexiClass = null;
        if (propDef.reference.$className)
        {
            refClsDef = self.getClassDefByName(propDef.reference.$className);
            if (!refClsDef)
                throw new Error(`Referenced class (Name=${propDef.reference.$className}) not found`);
            propDef.reference.classID = refClsDef.ClassID;
            delete propDef.reference.$className;
        }
        else
        {
            refClsDef = self.getClassDefByID(propDef.reference.classID);
            if (!refClsDef)
                throw new Error(`Referenced class (ID=${propDef.reference.classID}) not found`);
        }
        let revPropDef:IFlexiClassProperty = null;
        if (propDef.reference.reversePropertyID || propDef.reference.$reversePropertyName)
        {

            if (propDef.reference.reversePropertyID)
                revPropDef = self.getClassPropertyByID(propDef.reference.reversePropertyID);
            else
                if (propDef.reference.$reversePropertyName)
                {
                    revPropDef = self.getClassProperty(propDef.reference.classID, propDef.reference.$reversePropertyName);
                    delete propDef.reference.$reversePropertyName;
                }

            if (!revPropDef)
            // Not found
            {
                let revPropDef = {reference: {}, rules: {type: PROPERTY_TYPE.PROP_TYPE_LINK}} as IClassProperty;
                revPropDef.reference.classID = clsDef.ClassID;

                let refClsDef = self.getClassDefByID(propDef.reference.classID);
                self.doCreateClassProperty(refClsDef, propDef.reference.$reversePropertyName,
                    revPropDef);
            }
            else
            {
                let revClsDef = self.getClassDefByID(propDef.reference.classID);
                revPropDef.Data.rules.type = PROPERTY_TYPE.PROP_TYPE_LINK;
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
        if (propDef.reference.reversePropertyID)
        {
            // TODO
        }

        return refClsDef;
    }

    /*
     Applies changes for property that either used to be reference type or switched to be reference type.
     There is also a case when property stays reference but settings have changes (different class, different
     reverse property etc.)
     */
    private doAlterRefProp(clsDef:IFlexiClass, propertyName:string, curPropDef:IClassProperty,
                           propDef:IClassProperty)
    {
        var self = this;
        var newRef = false;
        var curRef = false;

        // Determining scope of changes
        if (propDef.rules.type === PROPERTY_TYPE.PROP_TYPE_LINK || propDef.rules.type === PROPERTY_TYPE.PROP_TYPE_OBJECT)
        {
            newRef = true;
        }

        if (curPropDef.rules.type === PROPERTY_TYPE.PROP_TYPE_LINK || curPropDef.rules.type === PROPERTY_TYPE.PROP_TYPE_OBJECT)
        {
            curRef = true;
        }

        if (!curRef && !newRef)
            return;

        if (newRef)
        {
            let refClsDef = self.initPropReference(clsDef, propertyName, propDef);

            let idPropID:string;
            // Check if it has property with role ID or Code
            let idProp = _.find(refClsDef.Data.properties,
                (pd:IClassProperty, pID:string)=>
                {
                    if ((pd.role & PROPERTY_ROLE.PROP_ROLE_ID) != 0)
                    {
                        idPropID = pID;
                        return true;
                    }
                    return false;
                });
            if (!idProp)
            {
                idProp = _.find(refClsDef.Data.properties,
                    (pd:IClassProperty, pID:string)=>
                    {
                        if ((pd.role & PROPERTY_ROLE.PROP_ROLE_CODE) != 0)
                        {
                            idPropID = pID;
                            return true;
                        }
                        return false;
                    });
            }
            if (idProp)
            {
                let pn = self.getNameByID(Number(idPropID));
                let sql = `update [.ref-values] set [Value] = 
                        (select rowid from [${refClsDef.Name}] where [${pn.Value}] = [.ref-values].[Value] limit 1),
                        ctlv = ctlv | $ctlv
                        where PropertyID = $PropertyID;`;
                self.DB.run.sync(self.DB, sql, {$PropertyID: 0});
            }
            else
                // Use ObjectIDs
            {
                let pn = self.getNameByID(Number(idPropID));
                let sql = `update [.ref-values] set [Value] = 
                        (select rowid from [${refClsDef.Name}] where rowid = [.ref-values].[Value] limit 1),
                        ctlv = ctlv | $ctlv
                        where PropertyID = $PropertyID;`;
                self.DB.run.sync(self.DB, sql, {$PropertyID: 0});
            }
        }
        else
        {
            if (curPropDef.reference.reversePropertyID &&
                (curPropDef.reference.reversePropertyID !== propDef.reference.reversePropertyID
                || curPropDef.reference.classID !== propDef.reference.classID))
            {
                let sql = `delete from [.class_properties] where PropertyID = $PropertyID`;
                self.DB.run(sql, {$PropertyID: curPropDef.reference.reversePropertyID})
            }
        }

    }

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
     ->reference
     */
    private doAlterClassProperty(clsDef:IFlexiClass, propertyName:string, propDef:IClassProperty, newPropName?:string)
    {
        var self = this;

        let propRow = _.find(clsDef.Properties,
            (prop:IFlexiClassProperty, idx:number)=>
            {
                return prop.Name === propertyName
            });

        if (propDef.$renameTo)
        // $renameTo has priority over newPropName
        {
            newPropName = propDef.$renameTo;
            delete propDef.$renameTo;
        }

        if (newPropName)
        {
            propRow.NameID = self.getNameByValue(newPropName).NameID;
        }

        var curPropDef = clsDef.Data.properties[propRow.PropertyID];

        var propUpdRequired = false;
        //
        var newRef = false;
        var curRef = false;

        // Determining scope of changes
        if (propDef.rules.type === PROPERTY_TYPE.PROP_TYPE_LINK || propDef.rules.type === PROPERTY_TYPE.PROP_TYPE_OBJECT)
        {
            newRef = true;
        }

        if (curPropDef.rules.type === PROPERTY_TYPE.PROP_TYPE_LINK || curPropDef.rules.type === PROPERTY_TYPE.PROP_TYPE_OBJECT)
        {
            curRef = true;
        }

        if (newRef && curRef)
        {
            throw new Error(
                `Cannot change definition of reference property ${propertyName}. 
Its definition has to be converted to scalar first, and then to new reference definition.`);
        }

        if (curRef || newRef)
        {
            propUpdRequired = true;
            self.doAlterRefProp(clsDef, propertyName, curPropDef, propDef);
        }

        // Compare index definition change
        var oldCtlv = propRow.ctlv;
        var newCtlv = Value_Control_Flags.CTLV_NONE;
        if ((oldCtlv & Value_Control_Flags.CTLV_INDEXING) !== (newCtlv & Value_Control_Flags.CTLV_INDEXING))
            propUpdRequired = true;

        // If new property definition is reference, assume job is done
        if (propDef.rules.type === PROPERTY_TYPE.PROP_TYPE_LINK || propDef.rules.type === PROPERTY_TYPE.PROP_TYPE_OBJECT)
            return;

        var newUnique = false;
        var curUnique = false;
        // Check if there are changes in indexing
        if ((propDef.role && (PROPERTY_ROLE.PROP_ROLE_CODE || PROPERTY_ROLE.PROP_ROLE_ID) !== 0) || propDef.unique)
        {
            newUnique = true;
        }

        if ((curPropDef.role && (PROPERTY_ROLE.PROP_ROLE_CODE || PROPERTY_ROLE.PROP_ROLE_ID) !== 0) || curPropDef.unique)
        {
            curUnique = true;
        }

        if (newUnique !== curUnique)
        {
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
            let sql = `select count(*) from [.ref-values] where [PropertyID] = $PropertyID 
                and ObjectID = (select ObjectID from [.objects] where ClassID = $ClassID limit 1) group by Value;`;
            let rows = self.DB.all.sync(self.DB, sql, {$PropertyID: propRow.PropertyID, $ClassID: clsDef.ClassID});
        }
        else
            if (Boolean(propDef.indexed) != Boolean(curPropDef.indexed))
            {
                /*
                 Indexed is treated after unique index constraint.
                 result of this change is that flag CTLV_INDEXED is set or cleared. Index gets updated automatically
                 as part of ctlv flags update
                 */
            }

        if (propDef.fastTextSearch != curPropDef.fastTextSearch)
        {
            /*
             Similarly to indexed flag, this attribute leads to update of CTLV_FULL_TEXT_INDEX flag.
             If this flag is set, trigger on [.ref-values] will update/insert/delete [.full_text_data] table.
             If this flag is cleared on property definition, no changes are applied to actual indexing, but
             all new updates/inserts will be ignoring full text index update. When flag toggles from true to
             false, property definition ctlv get flag CTLV_USED_FULL_TEXT_INDEX flag which indicates that
             some property values might be indexed via full text index, and MATCH function will apply both
             full text search and linear search
             */
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

    }

    /*
     Finds property by name in collection of class properties.
     Returns null if not found
     */
    private findClassPropertyByName(clsDef:IFlexiClass, propName:string):IClassProperty
    {
        let self = this;
        let n = self.getNameByValue(propName);
        let result = _.find(clsDef.Data.properties, (cp:IClassProperty, pID:string)=>
        {
            return Number(pID) === n.NameID;
        });
        return result;
    }

    /*
     Alters single class property definition
     */
    alterClassProperty(className:string, propertyName:string, propDef:IClassProperty, newPropName ?:string)
    {
        var self = this;
        self._lastActionReport = [];
        let clsDef = self.getClassDefByName(className);
        if (!clsDef)
            throw new Error(`Class ${className} not found`);
        let cp = self.findClassPropertyByName(clsDef, propertyName);
        if (cp)
        {
            self.doAlterClassProperty(clsDef, propertyName, propDef, newPropName);
        }
        else
        {
            self.doCreateClassProperty(clsDef, propertyName, propDef);
        }
    }

    /*

     */
    private doCreateClassProperty(clsDef:IFlexiClass, propertyName:string, propDef:IClassProperty)
    {

    }

    getInvalidObjects(className:string, markAsInvalid?:boolean):ObjectID[]
    {
        // TODO
        return null;
    }

    createClassProperty(className:string, propertyName:string, propDef:IClassProperty)
    {
        this.alterClassProperty(className, propertyName, propDef);
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
    private    initWhenClassExists(self:SQLiteDataRefactor, vars:ISyncVariables)
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