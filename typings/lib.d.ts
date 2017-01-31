/**
 * Created by slanska on 2016-04-01.
 */

/// <reference path="tsd.d.ts" />

// / <reference path="../js/lib/def/IClassDefinition.d.ts" />
// / <reference path="../js/lib/def/IDBRefactory.d.ts" />
///<reference path="../js/lib/def/definitions.d.ts"/>
// /<reference path="../src/typings/DBDefinitions.ts"/>

/*
 Extend Function prototype to allow sync calls
 */
interface Function
{
    sync(thisArg, ...args):any;
    sync<T>(thisArg, ...args):T;
}



