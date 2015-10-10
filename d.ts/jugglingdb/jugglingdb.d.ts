// Type definitions for juggling.js 0.3.2
// TODO Complete definitions
// Project:
// Definitions by: Ruslan Skorynin slan_ska
// Definitions: https://github.com/borisyankov/DefinitelyTyped

declare module jugglingdb
{
    export class BaseSQL
    {
        constructor();

        escapeName(name:string);

        tableEscaped(modelName:string);

        //query();

        command(sql:string, callback:(err:any, rslt:any)=>       void);

        queryOne(sql:string, callback:(err:any, rslt:any)=>       void);

        // TODO Type of model?
        table(model:any);

        // TODO Type of descr
        define(descr:any);

        // TODO
        defineProperty(model:AbstractClass, prop, params);

        // TODO
        exists(model:AbstractClass, id:any, callback:(err, rslt)=>void);

        // TODO
        save(model:AbstractClass, data, callback);

        // TODO
        find(model:AbstractClass, id, callback);

        escapeId(id: string);

        // TODO
        destroy(model:AbstractClass, id, callback);

// TODO
        count(model:AbstractClass, callback, where);

        // TODO
        updateAttrs(model, id, data, cb);

        // TODO
        disconnect();

        //
        automigrate(callback);

        // TODO
        dropTable(model, cb);

        //
        createTable(model, indexes, cb);

        log;
    }

    export interface IFilter
    {
        where:any;
        skip:number;
        limit:number;
        concurrent:any; // TODO
        offset:number;
        (error:Error, data:any);
    }

    export class ModelProperty
    {
        //constructor()
        //{
        //    this.minOccurences = 0;
        //    this.maxOccurences = 1;
        //}

        // One of values from list of primitive types OR class name
        type:String;

        // Max length
        limit:number;

        // Sets property to be indexed
        index:boolean;

        "default":()=>any;

        // DB field name
        name:string;

        // extra attributes
        minOccurences:number;
        maxOccurences:number;

        trackChanges:boolean;
        unique:boolean;
    }

    export class AbstractClass
    {
// TODO ???
        modelName: string;
        properties: ModelProperty[];
    }

    export interface Schema
    {
        define(className:string, properties:ModelProperty[], settings);

        defineProperty(model:AbstractClass, prop, params);

        extendModel(model:AbstractClass, props);

        automigrate(callback);

        autoupdate(callback);

        isActual(callback);

        log(sql, t);

        freeze();

        tableName(modelName:string);

        defineForeignKey(className:string, key, foreignClassName:string);

        disconnect(cb);

        // TODO Master - model?
        copyModel(Master);

        // TODO Returns transaction
        transaction();

        // String
        //JSON
        //Text
        //Date
        //Boolean
    }
}