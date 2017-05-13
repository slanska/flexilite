//
// Created by rs on 12.05.17.
//

#ifndef FLEXILITE_FLEXI_DATA_H
#define FLEXILITE_FLEXI_DATA_H

struct flexi_VTabCursor {
    struct sqlite3_vtab_cursor base;

    /*
     * This statement will be used for navigating through object list.
     * Depending on filter, query may vary
     */
    sqlite3_stmt *pObjectIterator;

    /*
     * This statement will be used to iterating through properties of object (by its ID)
     */
    sqlite3_stmt *pPropertyIterator;
    sqlite3_int64 lObjectID;

    /*
     * Actually fetched number of column values.
     * Reset to 0 on every next object fetch
     */
    int iReadCol;

    /*
     * Array of retrieved column data, by column index as it is defined in pVTab->pProps
     */
    sqlite3_value **pCols;

    /*
     * Indicator of end of file
     * May have 3 values:
     * -1: Next was never called. Assume Eof not reached
     * 0: Next was called, Eof was not reached yet
     * 1: Next was called and Eof was reached
     */
    short iEof;
};

int flexi_free_cursor_values(struct flexi_VTabCursor *cur);

int flexi_VTabCursor_free(struct flexi_VTabCursor *cur);

#endif //FLEXILITE_FLEXI_DATA_H
