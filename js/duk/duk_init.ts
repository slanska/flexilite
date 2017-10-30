/**
 * Created by slanska on 2017-10-24.
 */

import Database = require('better-sqlite3');
import {flexi} from "../lib/DBContext";

/*
Part of flexi typescript code which runs only when embedded with Duktape (not with node.js)
 */

// declare class DBContext {
//     constructor(db: Database) ;
// };

namespace flexi_duk {

    export let DBContexts: flexi.DBContext[] = [];

    /*
    Throws exception if dbcontext does not exist
     */
    export function getDBContext(dbcontextId: number): flexi.DBContext {
        let result = DBContexts[dbcontextId];
        if (!result)
            throw new Error(`Context ${dbcontextId} not found`);

        return result;
    }

    let nextCtxID = 0;

    export function newDBContext(db: Database) {
        let result = new flexi.DBContext(db);
        DBContexts[++nextCtxID] = result;
        return result;
    }
}