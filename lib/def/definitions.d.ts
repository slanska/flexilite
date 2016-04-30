/**
 * Created by slanska on 2015-12-09.
 */

/// <reference path="../../typings/lib.d.ts"/>

/*
 Extend ORM property definition with typed 'ext' attribute
 */
declare interface IORMPropertyDef
{
    ext?:ISchemaPropertyDefinition;
}

declare type NameID = number;