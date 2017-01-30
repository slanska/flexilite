/**
 * Created by slanska on 2016-04-01.
 */

///<reference path="../../../typings/lib.d.ts"/>

declare type ILastActionReportItem =
    {
        className:string,
        property?:string,
        message:string,
        status:'warning'|'error',
        numberOfObjects:number
    };

declare type ILastActionReport = ILastActionReportItem[];

interface IDBRefactory
{
    /*
     Returns report on results of last refactoring action
     */
    getLastActionReport():ILastActionReport;

    /*
     Alters existing class. New properties can be added, deleted or modified in any way. Properties can be also
     renamed if property's def has $renameTo value. If newName is set, class will be renamed. New class name should
     be unique.
     */
    alterClass(className:string, newClassDef?:IClassDefinition, newName?:string);

    /*
     Creates new class with the given name (should be unique).
     */
    createClass(name:string, classDef:IClassDefinition);

    /*
     Drops class, all related schemas, objects and references from database. Operation can be undone later.
     */
    dropClass(classID:number);

    /*
     Extracts existing properties from class definition and creates a new property of OBJECT or REFERENCE type.
     New class will be created/or existing one will be updated.
     Key properties can be optionally passed to check if identical object of the target class already exists.
     In this case, new linked object will not be created, but reference will be set to existing one.
     Example: Country column as string. Then class 'Country' was created.
     Property 'Country' was extracted to the new class and replaced with link
     @filter:IObjectFilter,
     @propIDs:PropertyIDs,
     @newRefProp:IClassPropertyDef,
     @targetClassID:number,
     @sourceKeyPropID:PropertyIDs,
     @targetKeyPropID
     */
    propertiesToObject(filter:IObjectFilter, propIDs:PropertyIDs, newRefProp:IClassPropertyDef,
                       targetClassID:number, sourceKeyPropID:PropertyIDs,
                       targetKeyPropID:PropertyIDs);

    /*
     Action opposite to propertiesToObject - properties of existing object will be treated as
     */
    objectToProperties(classID:number, refPropID:number, filter:IObjectFilter, propMap:IPropertyMap);



    /*
     Joins 2 non related objects into single object, using optional property map. Corresponding objects will be found using sourceKeyPropIDs
     and targetKeyPropIDs
     */
    structuralMerge(sourceClassID:number, sourceFilter:IObjectFilter, sourceKeyPropID:PropertyIDs,
                    targetClassID:number, targetKeyPropID:PropertyIDs, propMap:IPropertyMap);

    /*
     Splits objects vertically, i.e. one set of properties goes to class A, another - to class B.
     Resulting objects do not have any relation to each other
     */
    structuralSplit(sourceClassID:number, filter:IObjectFilter, targetClassID:number,
                    propMap:IPropertyMap, targetClassDef?:IClassDefinition);

    /*
     Change class ID of given objects. Updates schemas and possibly columns A..J to match new class schema
     */
    moveToAnotherClass(sourceClassID:number, filter:IObjectFilter, targetClassID:number, propMap:IPropertyMap);

    /*
     Removes duplicated objects. Updates references to point to a new object. When resolving conflict, selects object
     with larger number of references to it, or object that was updated more recently.
     */
    removeDuplicatedObjects(filter:IObjectFilter, compareFunction:string, keyProps:PropertyIDs, replaceTargetNulls:boolean);

    /*
     Split property into multiple: use SQL expressions
     */
    splitProperty(classID:number, sourcePropID:number, propRules:ISplitPropertyRules);

    /*
     Merge many properties into one: use SQL expressions
     */
    mergeProperties(classID:number, sourcePropIDs:number[], targetProp:IClassPropertyDef, expression:string);

    /*
     Alters single class property definition.
     Supported cases:
     1) Convert property type: scalar to reference. Existing value is assumed as ID/Text of referenced object (equivalent of foreign key
     in standard RDBMS)
     2) Change property type, number of occurences, required/optional flag. Scans existing data, if found objects that do not pass
     rules, objects are marked as HAS_INVALID_DATA flag. LastActionReport will have 'warning' entry
     3) Change property indexing: indexed, unique, ID, full text index etc. For unique indexes existing values are verified
     for uniqueness. Duplicates are marked as invalid objects. Last action report will have info on this with status 'warning'
     4) Changes in reference definition: different class, reversePropertyID, selectorPropID. reversePropertyID will update existing links.
     Other changes do not have effect on existing data
     5) Converts reference type to scalar. Extracts ID/Text/ObjectID from referenced objects, sets value to existing links,
     */
    alterClassProperty(className:string, propertyName:string, propDef:IClassPropertyDef, newPropName?:string);

    /*

     */
    createClassProperty(className:string, propertyName:string, propDef:IClassPropertyDef);

    /*

     */
    dropClassProperty(classID:number, propertyName:string);

    /*

     */
    importFromDatabase(options:IImportDatabaseOptions);

    /*
     Retrieves list of invalid objects for the given class (objects which do not pass property rules)
     Returns list of object IDs.
     @className - class name to perform validation on
     @markAsnInvalid - if set to true, invalid objects will be marked with CTLO_HAS_INVALID_DATA
     Note that all objects will be affected and valid objects will get this flag cleared.
     */
    getInvalidObjects(className:string, markAsInvalid?:boolean):ObjectID[];

    /*

     */
    // TODO
    //reorderArrayItems()

    //addReference()

    //deleteReference()
}

/*
 Settings for importing data from another database/CSV/JSON/XML file etc.
 */
interface IImportDatabaseOptions
{
    /*
     Optional source database connection string. If omitted, current database will be used
     Currently only SQLite is supported
     */
    sourceConnectionString?:string,

    /*
     Required name of source table
     */
    sourceTable:string,

    /*
     Required name of target table
     */
    targetTable:string,

    /*
     Optional mapping from source column names to target property names
     */
    columnNameMap?:IColumnNameMap;

    /*
     Optional SQL syntax where clause to be applied
     */
    whereClause?:string;
}

/*
 Declares contract for defining list of objects either by objectID(s), filter and/or ClassID
 */
interface IObjectFilter
{
    /*
     Required class ID
     */
    classID:number;

    /*
     Optional single object ID or array of object IDs for the classID
     */
    objectId?:number | [number];

    /*
     Optional where clause to be applied to classID (alternative to objectId)
     */
    filter?:any; // TODO orm filter
}

declare type ISplitPropertyRules = [{regex?:string, newPropDef:IClassPropertyDef}];

declare type IPropertyMap = [{sourcePropID:number, targetPropID:number}];

declare type PropertyIDs = number | number[];

declare type IColumnNameMap = {[columnName:string]:string};

declare type ObjectID = number;

