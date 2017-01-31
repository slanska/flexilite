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
        closeAsync(): Promise<Database>;

        runAsync(sql: string): Promise<Database>;
        runAsync(sql: string, ...params: any[]): Promise<Database>;

        getAsync(sql: string): Promise<any>;
        getAsync(sql: string, ...params: any[]): Promise<any>;

        allAsync(sql: string): Promise<any[]>;

        allAsync(sql: string, ...params: any[]): Promise<Database>;

        eachAsync(sql: string, callback?: (err: Error, row: any) => void): Promise<number>;
        eachAsync(sql: string, ...params: any[]): Promise<any>;

        exeAsync(sql: string): Promise<any>;

        prepareAsync(sql: string): Promise<Statement>;
        prepare(sql: string, ...params: any[]): Statement;
    }
}