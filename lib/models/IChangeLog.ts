/**
 * Created by slanska on 04.10.2015.
 */

module Flexilite.models
{
    export interface  IChangeLog
    {
        ID:number;
        TimeStamp:number, // Julianday with fractional time, following SQLite format
        OldKey:any;
        OldValue:any;
        Key:any;
        Value:any;
        ChangedBy:any
    }
}