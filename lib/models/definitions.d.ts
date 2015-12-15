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

/*
 Declares contract for saving individual property in .values or .objects (A-P columns) table
 */
interface IPropertyToSave
{
    /*
     ID of object to be inserted/updated
     */
    objectID:number;

    /*
     ID of host object
     */
    hostID?: number;

    /*
     Class definition which hold this property.
     Property definition is accessible via classDef.Properties[propName]
     */
    classDef:IClass;

    /*
     Name of property
     */
    propName: string;

    /*
     Optional property ID corresponding to property name
     */
    propID?:number;

    /*
     Property index (for array of values). For scalar property, it is 0.
     */
    propIndex:number;

    /*
     Property value
     */
    value?: any;
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
