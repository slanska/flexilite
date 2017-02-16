/**
 * Created by slanska on 2017-02-15.
 */

/*
 Settings for SQL unit test.
 All attributes are optional.
 If omitted, previous non empty value is used
 */
declare interface ISQLTestItem {
    /*
     Test group name. Corresponds to 'describe' in Mocha
     */
    describe?: string;

    /*
     Test name. Corresponds to 'it' in Mocha. If empty 'Test #XXX' will
     be used where XXX is sequential number of test item in the list
     */
    it?: string;

    /*
     Database to run tests. If no database specified (even in previous items),
     ':memory:' will be used
     */
    inDb?: string;

    /*
     Formatting string to be executed
     */
    inSql?: string;

    /*
     Arguments for input SQL
     */
    inArgs?: any[];

    /*
     List of numbers which corresponds to positions in inArgs.
     Those items should be strings and will be treated as file paths, relative to
     location of original test JSON file
     */
    inFileArgs?: number[],

    /*
     Path to the database to execute chkSql
     */
    chkDb?: string,

    /*
     Formatted string SQL to be executed and to return result which will be compared against result
     returned by running inSql
     */
    chkSql?: string;

    /*
     Array of arguments for chkSql
     */
    chkArgs?: any[];

    /*
     Similarly to inFileArgs, but for checking result
     */
    chkFileArgs?: number[],

    /*
     Scalar value or object/array to be verified against result of execution.
     If set, chkSql, chkDb, chkArgs are ignored
     */
    chkResult?: any;

    /*
     Name of another test spec file. Its contents will be injected instead of current
     item. If include is set, all other attributes are ignored.
     Path should be relative to the current test JSON file.
     */
    include?: string;

}

/*
 Format of input JSON file for SQL test
 */
declare type ISQLTestItems = ISQLTestItem[];