/**
 * Created by slanska on 2017-01-28.
 */

///<reference path="../../typings/sqlite3/sqlite3.d.ts"/>
///<reference path="../../typings/modules/bluebird/index.d.ts"/>

/*
 Declares sqlite3 classes with Promisifed methods
 */
declare module "sqlite3" {
    import Promise= require('bluebird');

    export interface Database {
        closeAsync(): Promise<any>;

        run(sql: string, callback?: (err: Error) => void): Database;
        run(sql: string, ...params: any[]): Database;

        get(sql: string, callback?: (err: Error, row: any) => void): Database;
        get(sql: string, ...params: any[]): Database;

        allAsync(sql: string):Promise<any[]>;

        all(sql: string, ...params: any[]): Database;

        each(sql: string, callback?: (err: Error, row: any) => void, complete?: (err: Error, count: number) => void): Database;
        each(sql: string, ...params: any[]): Database;

        exec(sql: string, callback?: (err: Error) => void): Database;

        prepare(sql: string, callback?: (err: Error) => void): Statement;
        prepare(sql: string, ...params: any[]): Statement;

        serialize(callback?: () => void): void;
        parallelize(callback?: () => void): void;

    }
}