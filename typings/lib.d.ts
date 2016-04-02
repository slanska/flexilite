/**
 * Created by slanska on 2016-04-01.
 */

/// <reference path="tsd.d.ts" />

/// <reference path="node-orm-sync.d.ts" />

/// <reference path="../lib/def/IClassDefinition.d.ts" />
/// <reference path="../lib/def/ISchemaDefinition.d.ts" />
/// <reference path="../lib/def/IDBRefactory.d.ts" />
///<reference path="../lib/def/definitions.d.ts"/>

/*
 Extend Function prototype to allow sync calls
 */
interface Function
{
    sync(thisArg, ...args):any;
    sync<T>(thisArg, ...args):T;
}



