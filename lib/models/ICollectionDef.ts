/**
 * Created by slanska on 04.10.2015.
 */

/// <reference path="../../typings/tsd.d.ts"/>

/*
Structure of .collections table
 */
declare interface ICollectionDef
{
    /*
    Unique auto-incremened collection ID
     */
    CollectionID? : number;

    /*
    ID of collection name
     */
    NameID: number;

    /*
    Current base schema ID (latest version of base schema)
     */
    BaseSchemaNameID?: number;

    /*
    If true, defines collection as system: this one cannot be modified or deleted by end user
     */
    SystemCollection?: boolean;

    /*
    If true, indicates that view definition is outdated and needs to be regenerated
     */
    ViewOutdated?: boolean | number;

    ctloMask?: number;

    /*
    Optional maximum number of items in the collection
     */
    Capacity?: number;

    /*
    Optional property IDs for mapped columns
     */
    A?: number;
    B?: number;
    C?: number;
    D?: number;
    E?: number;
    F?: number;
    G?: number;
    H?: number;
    I?: number;
    J?: number;
}
