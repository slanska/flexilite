/**
 * Created by slanska on 2016-04-01.
 */

/*
References to node-orm TypeScript definitions and
missing in the original library definitions for custom driver development.
TODO: Merge these changes with node-orm master
 */

/// <reference path="../node_modules/orm/lib/TypeScript/orm.d.ts" />
/// <reference path="../node_modules/orm/lib/TypeScript/sql-query.d.ts" />

/// <reference path="tsd.d.ts"/>

/*
 node-orm2 declaration of individual property
 */
//TODO: move to node-orm2 d.ts
declare interface IORMPropertyDef
{
    klass?: 'primary' | 'hasOne' | 'hasMany'
    mapsTo?: string;
    name?: string;
    type?: string; // 'integer' | 'enum' (values) | 'binary' | 'text' | 'boolean' | 'serial' | 'object' | 'date' | 'number' | 'point'
    time?:boolean;
    ui?: {view?: string, width?: number}; // TODO Other UI settings
    unique?: boolean;
    indexed?:boolean;
    defaultValue?: any;
    big?: boolean;
    size?:number;
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
    field:{[key:string]:IORMPropertyDef},
    getAccessor:string,// Function name
    hasAccessor:string,// Function name

    /*
     TODO
     */
    hooks:any;

    /*
     Name of properties in referenced class (detail/linked)
     */
    mergeAssocId:{[key:string]:IORMPropertyDef},

    /*
     Names of properties in the referencing class (master)
     */
    mergeId:{[key:string]:IORMPropertyDef},

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
    properties:{[propName:string]: IORMPropertyDef};

    extension:any;
    id?:string[]; // array of ID fields
    allProperties:{[propName:string]: IORMPropertyDef};
    indexes:any[];
    customTypes:any[];
    extend_associations:any[];

    one_associations:IHasOneAssociation[];

    many_associations?:IHasManyAssociation[];
}








