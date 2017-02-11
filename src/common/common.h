//
// Created by slanska on 2017-02-11.
//

#ifndef FLEXILITE_COMMON_H
#define FLEXILITE_COMMON_H

/*
 * Utility macros
 * Designed to provide uniformed way to handle result from sqlite API calls.
 * Should be used in the following pattern for function:
 *
 * int result = SQLITE_OK; // int result must be declared
 * ... API calls
 *
 * goto FINALLY; // skip CATCH
 *
 * CATCH:
 * clean up on error
 * return result; // optionally, return error code
 * FINALLY:
 * clean up when done regardless if success or failure
 * return result;
 *
 * result declaration, CATCH and FINALLY must be always present in the function body
 * if one of the following macros is used
 *
 */
#define CHECK_CALL(call)       result = (call); \
        if (result != SQLITE_OK) goto CATCH;
#define CHECK_STMT(call)       result = (call); \
        if (result != SQLITE_DONE && result != SQLITE_ROW) goto CATCH;

#define CHECK_MALLOC(v, s) v = sqlite3_malloc(s); \
        if (v == NULL) { result = SQLITE_NOMEM; goto CATCH;}


#endif //FLEXILITE_COMMON_H
