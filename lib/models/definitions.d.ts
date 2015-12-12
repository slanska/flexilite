/**
 * Created by slanska on 2015-12-09.
 */

/// <reference path="../../typings/tsd.d.ts"/>


interface IDataToSave
{
    SchemaData?:any;
    ExtData?:any;
}

interface IDropOptions
{
    table:string;
    properties:[any];
    one_associations:[any];
    many_associations:[any];
}

interface ISyncOptions extends IDropOptions
{
    extension:any;
    id:any;
    allProperties:[string, Flexilite.models.IPropertyDef];
    indexes:[any];
    customTypes:[any];
    extend_associations:[any];
}

// TODO Handle hasOne and extend association

interface IHasManyAssociation
{
}
