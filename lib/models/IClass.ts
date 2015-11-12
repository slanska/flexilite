/**
 * Created by slanska on 04.10.2015.
 */

/// <reference path="../../typings/tsd.d.ts"/>

module Flexilite.models
{
    /*

     */
    export interface IClass
    {
        ClassID? : number;
        ClassName: string;
        SchemaID?: number;
        SystemClass?: boolean;
        DefaultScalarType: string;
        TitlePropertyID?: number;
        SubTitleProperty?: number;
        SchemaXML?: string;
        SchemaOutdated?: boolean;
        MinOccurences?: number;
        MaxOccurences?: number;
        DBViewName: string;
        ctloMask?: number;

        Properties: [IClassProperty];
    }
}
