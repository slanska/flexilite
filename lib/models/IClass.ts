/**
 * Created by slanska on 04.10.2015.
 */

/// <reference path="../../typings/tsd.d.ts"/>

/*

 */
declare interface IClass
{
    ClassID? : number;
    ClassName: string;
    SchemaID?: number;
    SystemClass?: boolean;
    DefaultScalarType: string;
    TitlePropertyID?: number;
    SubTitleProperty?: number;

    // TODO Needed?
    SchemaXML?: string;

    SchemaOutdated?: boolean | number;
    MinOccurences?: number;
    MaxOccurences?: number;
    DBViewName: string;
    ctloMask?: number;
    Unique?: boolean;
    Indexed?:boolean;
    ExtData?:any;
    ValidationRegex: string;
    StrictSchema:boolean;

    Properties: {[propName: string]: IClassProperty};
}
