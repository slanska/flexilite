/**
 * Created by slanska on 2015-12-09.
 */

/// <reference path="../../typings/tsd.d.ts"/>


/*
Defines contract for object data to be inserted or updated.
 */
interface IDataToSave
{
    /*
    Portion of object data which is defined by object's class ("schema" data)
     */
    SchemaData?:any;

    /*
    Portion of object data which is NOT defined by object's class ("non-schema" data)
     */
    ExtData?:any;

    /*
    Portion of object data which are defined in schema and are other objects (non atomic values, and not Date nor Buffer)
     */
    LinkedSchemaObjects?: any;

    /*
    Portion of non schema object data, which are objects themselves.
    Such objects will be inserted into .objects table with flag "NonSchema"
     */
    LinkedExtObjects?: any;
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
