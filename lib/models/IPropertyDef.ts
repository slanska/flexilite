/**
 * Created by slanska on 2015-11-09.
 */

declare interface  IPropertyDef
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
    klass?: string; // primary, hasOne, hasMany
    mapsTo?: string;
    name?: string;
    type?: string; // integer, enum (values), binary, text, boolean, serial, object
    ui?: {view?: string, width?: number}; // TODO Other UI settings
    unique?: boolean;
    indexed?:boolean;
    defaultValue?: any;
    big?: boolean;
}
