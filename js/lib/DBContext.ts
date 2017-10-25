/**
 * Created by slanska on 2017-10-24.
 */

//v/<reference path="../../node_modules/@types/better-sqlite3/index.d.ts"/>

import * as Database from 'better-sqlite3';

interface RunResult {
    changes: number;
    lastInsertROWID: number; // TODO Integer.IntLike;
}

declare class Statement {
    database: Database;
    source: string;
    returnsData: boolean;
    constructor(db: Database, sources: string[]);

    run(...params: any[]): RunResult;
    get(...params: any[]): any;
    all(...params: any[]): any[];
    each(params: any, cb: (row: any) => void): void;
    each(cb: (row: any) => void): void;
    each(...params: any[]): void;
    pluck(toggleState?: boolean): this;
    bind(...params: any[]): this;
    safeIntegers(toggleState?: boolean): this;
}


module flexi {
    export class DBContext {
        stmts: { [sql: string]: Statement } = {};

        constructor(protected db: Database) {
        }


        commands: { [cmd: string]: any } = {
            'create class': this.createClass,
            'class create': this.createClass,
            'alter class': this.alterClass,
            'class alter': this.alterClass,
            'drop class': void 0,
            'class drop': void 0,
            'create property': void 0,
            'property create': void 0,
            'alter property': void 0,
            'property alter': void 0,
            'drop property': void 0,
            'property drop': void 0,
            'rename property': void 0,
            'property rename': void 0,
            'merge property': void 0,
            'property merge': void 0,
            'split property': void 0,
            'property split': void 0,
            'properties to object': void 0,

        };

        private getSqlStmt(sql:string):Statement
        {
            return null;
        }

        run(...args: string[]): string {
            const cmdName = args[0];
            const cmd = this.commands[cmdName];
            if (!cmd)
                throw new Error(`Command "${cmdName}" not found`);

            args = args.splice(0, 1);
            let result = cmd.apply(this, args);
            return result;
        }

        public createClass(className: string, classDefJSON: string, createVTable: boolean = false) {
        }

        public alterClass(className: string, classDefJSON: string, createVTable: boolean = false) {
        }


    }


}