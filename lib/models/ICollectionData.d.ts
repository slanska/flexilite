/**
 * Created by slanska on 2016-03-27.
 */

/*
Declarations for .collections Data 
 */
declare interface IClassPropertyDef
{
    propertyID:number;
}

declare interface IClassDef
{
    ClassID:number;
    CurrentSchemaID:number;
    Properties:[string, IClassPropertyDef];
}
