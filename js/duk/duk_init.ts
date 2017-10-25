/**
 * Created by slanska on 2017-10-24.
 */

/*
Part of flexi typescript code which runs only when embedded with Duktape (not with node.js)
 */

module flexi {

    export let DBContexts: [] = [];

    /*
    Throws exception if dbcontext does not exist
     */
    export function getDBContext(dbcontextId: number): DBContext {
        let result = DBContexts[dbcontextId];
        if (!result)
            throw new Error(`Context ${dbcontextId} not found`);

        return result;
    }

    let nextCtxID = 0;

    export function newDBContext(db: Database) {
        let result = new DBContext(db);
        DBContexts[++nextCtxID] = result;
        return result;
    }
}