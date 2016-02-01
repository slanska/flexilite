/**
 * Created by slanska on 2016-01-16.
 */

/*
 Declares contract for defining list of objects either by objectID(s), filter and/or ClassID
 */
declare interface IObjectFilter
{
    objectId?: number | [number];
    classId?: number;
    filter?: any;
}

/*

 */
declare interface IPropertyDef
{

    jsonPath: string;
    name: string;
}

/*

 */
declare interface ISchemaDef
{
    properties: [number, IPropertyDef]
}

declare interface IClassPropertyDef
{
    propertyID: number;
}

declare interface IClassDef
{
    ClassID:number;
    CurrentSchemaID:number;
    Properties:[string, IClassPropertyDef];
}

import d = require( './Driver');


// FIXME: rename to SQLiteDataRefactor
export class SQLiteDataRefactor
{

    constructor (private ormDriver)
    {

    }

    // Create class
    createClass(className:string, copyFrom:{classIdOrName?:number|string, schemaId?:number}):IClassDef
    {
        var result:IClassDef;
        return result;
    }

    // Delete class
    deleteClass()
    {
    }

    // Rename class
    renameClass()
    {
    }

    // Extract object
    /*
     Parameters:
     filter: ObjectFilter
     class: ID | ClassDef
     propertyMapping: [{propID, jsonPath, propName}]


     Create new class (if needed)
     Create schema for new class (if needed)
     Generate views - JSONIC and COLUMNIC
     Insert new object into JSONIC view with path (or extracted content?)
     -- Update old objects by removing content?
     */
    public extractObject(filter:IObjectFilter, mappings:[IPropertyDef])
    {

    }

    // Map object
    /*
     Same as extract but new object is stored as reference (JsonPath).
     If object is already mapped, JsonPath is concatenated
     */
    public mapObject(filter:IObjectFilter, mappings:[IPropertyDef])
    {

    }

    // Add property
    /*
     Update schema. Trigger will create new record with old data.
     Set Class.CurrentSchemaID = new.SchemaID
     */
    addProperty(schema:ISchemaDef, propertyId:number, propDef:IPropertyDef)
    {
    }

    // Insert object
    /*
     In view trigger, ref properties are processed individually (hard coded, based on schema definition)
     Insert child objects, with JsonPath
     Insert into ref-values
     */
    insertObject(classIdOrName:number | string, data:any):number
    {
        return 0; // FIXME
    }

    // Update object
    /*
     new JSON is merged from old JSON and new property values
     find child objects (by HostID), update with new JSON subset (based on object's JsonPath)
     if old.Data <> new.Data (to apply validation).
     Recursively called in trigger
     */
    updateObject(objectId:number, data:any, oldData?:any)
    {
    }

    // Delete object
    /*
     Update child objects, left after removing all ref-values, matching by Host and
     JsonPath. Set extracted JSON from old.Data, based on their JsonPath
     */
    deleteObject(objectId:number)
    {
    }

    // Delete property
    deleteProperty(schema:ISchemaDef, propertyId:number)
    {
    }


    // Rename property
    renameProperty(schema:ISchemaDef, propertyId:number, newPropertyName:string)
    {
    }

    /*
     Updates property(ies) definition.
     Actions:
     - saves new schema in the database
     - updates class.CurrentSchemaID
     - generates views for the class
     */
    updateProperty(schema:ISchemaDef, propertyId:number, propDef:IPropertyDef)
    {

    }

    // Property: scalar -> collection

    // Split property into multiple: use SQL expressions
    splitProperty()
    {

    }

    // Merge many properties into one: use SQL expressions
    mergeProperties()
    {

    }

    // Inject one object into another
    injectObjects()
    {
    }

    // Move properties from one object to another (partial extract)
    moveProperties()
    {
    }


    // Extend object with other class (mixin)
    extendObject(filter:IObjectFilter, classIdOrName:number | string)
    {
    }

    // add relation

    // delete relation

//
}