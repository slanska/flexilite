//
// Created by rs on 12.05.17.
//

#ifndef FLEXILITE_FLEXI_DATA_H
#define FLEXILITE_FLEXI_DATA_H

typedef enum
{
    FLEXI_DATA_COL_SELECT = 0,
    FLEXI_DATA_COL_CLASS_NAME = 1,
    FLEXI_DATA_COL_FILTER = 2,
    FLEXI_DATA_COL_ORDER_BY = 3,
    FLEXI_DATA_COL_LIMIT = 4,
    FLEXI_DATA_COL_ID = 5,
    FLEXI_DATA_COL_SKIP = 6,
    FLEXI_DATA_COL_DATA = 7,
    FLEXI_DATA_COL_BOOKMARK = 8,
    FLEXI_DATA_COL_USER = 9,
    FLEXI_DATA_COL_FETCH_DEPTH = 10

} FLEXI_DATA_COLUMNS;

struct flexi_VTabCursor
{
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

/*
 * Proxy virtual table module for flexi_data
 */
struct FlexiDataProxyVTab_t
{
    /*
    * Should be first field. Used for virtual table initialization
    */
    sqlite3_vtab base;

    /*
     * Real implementation
     */
    sqlite3_module *pApi;

    struct flexi_Context_t *pCtx;

    /*
     * Class is defined by its ID. When class definition object is needed, pCtx is used to get it by ID
     * Applicable to both AdHoc and virtual table
     */
    sqlite3_int64 lClassID;

    /*
     * These fields are applicable to ad-hoc
     */
    struct AdHocQryParams_t *pQry;
};

typedef struct FlexiDataProxyVTab_t FlexiDataProxyVTab_t;

#endif //FLEXILITE_FLEXI_DATA_H
