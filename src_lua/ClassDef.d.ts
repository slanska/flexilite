/**
 * Created by slanska on 2017-11-30.
 */


///<reference path="./PropertyDef.d.ts"/>

/*
ClassDef declaration
 */

declare interface ClassDef {
    Properties: { [propName: string]: PropertyDef }
}