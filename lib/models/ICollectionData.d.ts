/**
 * Created by slanska on 2016-03-27.
 */

/*
 Declarations for .collections Data
 */

/*
 Collection property metadata
 */
interface ICollectionSchemaProperty
{
    indexed?:boolean;
    unique?:boolean;
    defaultValue?:any;

    /*
     Name ID for column name as it is presented in the database view
     */
    columnNameID?:number;

    labelID?:number;

}

/*
 Structure of .collections.SchemaRules
 */
interface ICollectionSchemaRules
{
    /*
     Mapping to shortcut columns A..J
     */
    mapping:{[columnName:string]:number};

    /*
     Properties definition for view generation
     */
    properties:{[propID:number]:ICollectionSchemaProperty};
}
