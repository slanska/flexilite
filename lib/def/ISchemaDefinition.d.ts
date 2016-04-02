/**
 * Created by slanska on 2016-03-27.
 */


/// <reference path="../../typings/lib.d.ts"/>

/*
 Definitions for .schemas Data JSON column
 */

interface IPropertyMapSettings
{
    jsonPath:string;

    /*
     For boolean properties, defined as items in array. For example:
     ['BoolProp1', 'BoolProp2', 'BoolProp3']. Presense of item in array means property `true` value.
     */
    itemInArray?:string;


}

interface ISchemaPropertyDefinition
{
    map:IPropertyMapSettings;
}

/*
 Structure of Data fields in .schemas table
 */
interface ISchemaDefinition
{
    ui?:{
        defaultTemplates?:{
            form?:string;
            table?:string;
            item?:string;
            view?:string;
        };
    };
    properties:{[propertyID:number]:ISchemaPropertyDefinition};
}

/*
Extend ORM property definition with typed 'ext' attribute
 */
declare interface IORMPropertyDef
{
    ext?:ISchemaPropertyDefinition;
}


