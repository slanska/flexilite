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
 * goto EXIT; // skip ONERROR
 *
 * ONERROR:
 * clean up on error
 * return result; // optionally, return error code
 * EXIT:
 * clean up when done regardless if success or failure
 * return result;
 *
 * result declaration, ONERROR and EXIT must be always present in the function body
 * if one of the following macros is used
 *
 */
#include <stdbool.h>

#ifdef  SQLITE_CORE

#include <sqlite3.h>

#else

#include <sqlite3ext.h>

#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef SQLITE_AMALGAMATION

typedef unsigned int u32;
typedef unsigned char u8;

#endif

typedef sqlite3_uint64 u64;

enum CHANGE_STATUS
{
    CHNG_STATUS_NOT_MODIFIED = 0,
    CHNG_STATUS_ADDED = 1,
    CHNG_STATUS_MODIFIED = 2,
    CHNG_STATUS_DELETED = 3
};

typedef enum CHANGE_STATUS CHANGE_STATUS;

// TODO
enum REF_PROP_ROLE
{
    REF_PROP_ROLE_MASTER = 0,
    REF_PROP_ROLE_LINK = 0,
    REF_PROP_ROLE_NESTED = 0,
    REF_PROP_ROLE_DEPENDENT = 0
};

#define CHECK_CALL(call) \
        result = (call); \
        if (result != SQLITE_OK) \
        { \
            goto ONERROR; \
        }

#define CHECK_SQLITE(db, call) \
        result = (call); \
        if (result != SQLITE_OK) \
        { \
            const char *zErrStr = sqlite3_errmsg(db); \
            printf("\nError %d:%s in \"%s:%d\", function %s", result, zErrStr, __FILE__, __LINE__, __func__); \
            goto ONERROR; \
        }

#define CHECK_STMT_PREPARE(db, zSQL, stmt) \
    result = sqlite3_prepare_v2(db, zSQL, -1, stmt, NULL); \
    if (result != SQLITE_OK) \
    { \
            goto ONERROR; \
    }

/*
 * Checks result of sqlite3_step. SQLITE_DONE and SQLITE_ROW are ok.
 * Other codes are treated as error
 */
#define CHECK_STMT_STEP(stmt, db)       result = sqlite3_step(stmt); \
        if (result != SQLITE_DONE && result != SQLITE_ROW) \
        { \
            CHECK_SQLITE(db, result); \
        }

#define CHECK_NULL(v) if (v == NULL) { result = SQLITE_NOMEM; goto ONERROR;}

#define CHECK_MALLOC(v, s) v = sqlite3_malloc(s); CHECK_NULL(v)

#define ARRAY_LEN(arr)   (sizeof(arr) / sizeof(arr[0]))

#define STR_EMPTY(s) (s == NULL || strcmp(s, "") == 0)

/* Mark a function parameter as unused, to suppress nuisance compiler
** warnings. */
#ifndef UNUSED_PARAM
# define UNUSED_PARAM(X)  (void)(X)
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
typedef void iterateeFunc(const char *zKey, const sqlite3_int64 index, void *pData,
                          const var collection, var param, bool *bStop);

typedef union any
{
    char *zValue;
    long long int i64;

} any;

#ifdef __cplusplus
}
#endif

#endif //FLEXILITE_COMMON_H
