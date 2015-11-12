/**
 * Created by slanska on 04.10.2015.
 */

module Flexilite.models
{
    export interface  IChangeLog
    {
        ID:number;
        TimeStamp:number, // Julainday with fractions
        OldKey:any;
        OldValue:any;
        Key:any;
        Value:any;
        ChangedBy:any
    }
}