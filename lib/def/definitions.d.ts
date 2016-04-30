/**
 * Created by slanska on 2015-12-09.
 */

/// <reference path="../../typings/lib.d.ts"/>

/*
 Miscellaneous constants for Flexilite
 */

// declare const enum SQLITE_OPEN_FLAGS
// {
//     SHARED_CACHE = 0x00020000,
//     WAL = 0x00080000
// }

/*
 Integer constants defined as enum
 */
declare const enum FLEXILITE_LIMITS
{
    MaxOccurences = 1 << 31,
    MaxObjectID = 1 << 31
}

/*
 Extend ORM property definition with typed 'ext' attribute
 */
declare interface IORMPropertyDef
{
    ext?:ISchemaPropertyDefinition;
}

declare type NameID = number;