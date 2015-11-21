/**
 * Created by slanska on 2015-11-09.
 */

module Flexilite.models
{
    export interface  IPropertyDef
    {
        ext?: {
            mappedTo?: string,
            trackChanges?: boolean;
            minOccurences?: number;
            maxOccurences?: number;
            maxLength?: number;
            titleSingle?: string;
            titlePlural?: string;
            validateRegex?: string;
        };
        klass?: string;
        mapsTo?: string;
        name?: string;
        type?: string;
        ui?: {view?: string, width?: number}; // TODO Other UI settings
        unique?: boolean;
        indexed?:boolean;
        defaultValue?: any;
    }
}