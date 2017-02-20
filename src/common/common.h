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
#include <stdbool.h>

#define CHECK_CALL(call)       result = (call); \
        if (result != SQLITE_OK) goto CATCH;

/*
 * Checks result of sqlite3_step. SQLITE_DONE and SQLITE_ROW are ok.
 * Other codes are treated as error
 */
#define CHECK_STMT(call)       result = (call); \
        if (result != SQLITE_DONE && result != SQLITE_ROW) goto CATCH;

#define CHECK_MALLOC(v, s) v = sqlite3_malloc(s); \
        if (v == NULL) { result = SQLITE_NOMEM; goto CATCH;}

/* Mark a function parameter as unused, to suppress nuisance compiler
** warnings. */
#ifndef UNUSED_PARAM
# define UNUSED_PARAM(X)  (void)(X)
#endif

#ifndef SQLITE_AMALGAMATION
/* Unsigned integer types.  These are already defined in the sqliteInt.h,
** but the definitions need to be repeated for separate compilation. */

typedef unsigned int u32;
typedef unsigned char u8;
#endif

typedef void *var;

/*
 * @brief: Function callback for generic collection iteration (hash tables, arrays etc.)
 * @param zKey - (applicable to hash tables)
 * @param index - (index in array or sequential iteration number for non-array collections)
 * @param pData - item data
 * @param collection - collection instance (hash table or array)
 * @param bStop - should be set to true by iterateeFunc to stop iteration and return last processed item
 */
typedef void iterateeFunc(const char *zKey, int index, void *pData,
                      var collection, var param, bool *bStop);

#endif //FLEXILITE_COMMON_H
