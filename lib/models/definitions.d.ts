/**
 * Created by slanska on 2015-12-09.
 */

/// <reference path="../../typings/tsd.d.ts"/>

/*
 Defines contract for object data to be inserted or updated.
 */
interface IDataToSave
{
    /*
     Portion of object data which is defined by object's class ("schema" data)
     */
    SchemaData?:any;

    /*
     Portion of object data which is NOT defined by object's class ("non-schema" data)
     */
    ExtData?:any;
}

/*
 Defines contract for basic EAV property data
 */
interface IEAVBase
{
    /*
     ID of object to be inserted/updated
     */
    objectID:number;

    /*
     ID of host object
     */
    hostID?:number;

    /*
     Optional property ID corresponding to property name
     */
    propID?:number;

    /*
     Property index (for array of values). For scalar property, it is 0.
     */
    propIndex:number;

    /*
     Property value
     */
    value?:any;
}

/*
 Declares contract for saving individual property in .values or .objects (A-P columns) table
 */
interface IPropertyToSave extends IEAVBase
{

    /*
     Class definition which hold this property.
     Property definition is accessible via classDef.Properties[propName]
     */
    //classDef:IFlexiCollection;

    /*
     Name of property
     */
    propName:string;
}


interface IDropOptions
{
    table:string;
    properties:[any];
    one_associations:[any];

    /*
     TODO Finalize exact typeß
     */
    many_associations:[any];
}

interface IModel
{
    addProperty(propIn, options);
    afterAutoFetch(cb);
    afterCreate(cb);
    afterLoad(cb);
    afterRemove(cb);
    afterSave(cb);
    aggregate();
    all();
    allProperties:any;
    arguments:any;
    beforeCreate(cb);
    beforeRemove(cb);
    beforeSave(cb);
    beforeValidation(cb);
    caller:any;
    clear(cb);
    count(cb);
    create();
    drop(cb);
    exists();
    extendsTo(name:string, properties, opts);
    find();
    findByOwner();
    get();
    hasMany();
    hasOne();
    id:string[];
    keys:string[];
    length:number;
    name:string;
    one();
    prependValidation(key, validation);
    properties:{[propName:string]:any}; // FIXME Property def
    prototype:any; // FIXME Model
    settings:{get(key, def), set(key, value), unset()};
    sync(cb);
    table:string;
    uid:string;

}

interface IHasManyAssociation
{
    addAccessor:string, // Function name
    autoFetch:boolean,
    autoFetchLimit:number,
    delAccessor:string,// Function name
    field:{[key:string]:INodeORMPropertyDef},
    getAccessor:string,// Function name
    hasAccessor:string,// Function name

    /*
     TODO
     */
    hooks:any;

    /*
     Name of properties in referenced class (detail/linked)
     */
    mergeAssocId:{[key:string]:INodeORMPropertyDef},

    /*
     Names of properties in the referencing class (master)
     */
    mergeId:{[key:string]:INodeORMPropertyDef},

    mergeTable:string, // Many2Many table name
    model:IModel,
    name:string, // relation name
    setAccessor:string,// Function name

    /*
     Additional properties for the Many2Many table
     */
    props:any
}

interface IHasOneAssociation
{
    autoFetch:boolean,
    autoFetchLimit:number,
    delAccessor:string,// Function name
    extension:boolean,

    /*
     Collection of fields which map to ID of referenced table
     */
    field:{[propname:string]:{
        big?:boolean,
        mapsTo?:string,
        name:string,
        required?:boolean,
        size?:number,
        time?:boolean,
        type?:string,
        unsigned?:boolean,
        values?:any}},
    getAccessor:string,// Function name
    hasAccessor:string,// Function name
    model:IModel,

    /*
     Name of referenced table/class
     */
    name:string,
    required:boolean,

    /*
     Name of back reference (reversed) property
     */
    reverse:string,

    /*
     true for reversed property
     */
    reversed:boolean,

    setAccessor:string// Function name
}

/*
 Node-orm2 model definition for synchronization with database schema
 */
interface ISyncOptions
{
    table:string;
    properties:{[propName:string]: INodeORMPropertyDef};

    extension:any;
    id?:string[]; // array of ID fields
    allProperties:{[propName:string]: INodeORMPropertyDef};
    indexes:any[];
    customTypes:any[];
    extend_associations:any[];

    one_associations:IHasOneAssociation[];

    many_associations?:IHasManyAssociation[];
}

/*
 Integer constants defined as enum
 */
declare const enum FLEXILITE_LIMITS
{
    MaxOccurences = 1 << 31,
    MaxObjectID = 1 << 31
}

/*
 Extend functions to allow sync calls
 */
interface Function
{
    sync(thisArg, ...args):any;
    sync<T>(thisArg, ...args):T;
}







