/**
 * Created by slanska on 2015-12-09.
 */

/// <reference path="../../typings/lib.d.ts"/>

/*
 Miscellaneous constants for Flexilite
 */

declare const enum SQLITE_OPEN_FLAGS
{
    SHARED_CACHE = 0x00020000,
    WAL = 0x00080000
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
 Defines contract for object data to be inserted or updated.
 */
// TODO Needed?
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