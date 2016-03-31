/**
 * Created by slanska on 2015-11-09.
 */

/// <reference path="./ISchemaData.d.ts"/>

/*
node-orm2 declaration of individual property
 */
//TODO: move to node-orm2 d.ts
declare interface IORMPropertyDef
{
    ext?: ISchemaPropertyDefinition;
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
