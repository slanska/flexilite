/**
 * Created by slanska on 2015-11-16.
 */

/// <reference path="../../typings/tsd.d.ts"/>



export module Flexilite.models
{
    /*

     */
    export class ClassDef implements ICollectionDef
    {
        ClassName:string;
        SchemaID:number;
        SystemClass:boolean;
        DefaultScalarType:string;
        TitlePropertyID:number;
        SubTitleProperty:number;
        SchemaXML:string;
        SchemaOutdated:boolean;
        MinOccurences:number;
        MaxOccurences:number;
        DBViewName:string;
        ctloMask:number;
        Unique:boolean;
        Indexed:boolean;
        ExtData:any;
        ValidationRegex: string;
        StrictSchema:boolean;

        ClassID:number;

        Properties:{[propName: string]: IClassProperty};
    }
}