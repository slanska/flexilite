//
// Created by slanska on 2017-02-26.
//

#ifndef CLASS_REF_DEF_H
#define CLASS_REF_DEF_H

#include <stdbool.h>
#include "../util/Array.h"

/*
 * Holds entity name and corresponding ID
 * Used for user-friendly way of specifying classes, properties, enums, names.
 * Holder of this struct is responsible for freeing name
 */
struct flexi_MetadataRef_t
{
    char *name;
    sqlite3_int64 id;

    //    enum CHANGE_STATUS eChngStatus;

    /*
     * If true, name is owned by this struct and should be freed in destructor
     * Otherwise, it is owned by other object
     */
    bool bOwnName;
};

typedef struct flexi_MetadataRef_t flexi_MetadataRef_t;

void flexi_metadata_ref_free(flexi_MetadataRef_t *);

/*
 * Compares 2 arrays of metadata_ref structs.
 * Returns true if both arrays have identical definitions (exact order is not important)
 * Performs sort on r1 for faster processing
 * cnt - number of entries in the array
 */
bool flexi_metadata_ref_compare_n(flexi_MetadataRef_t *r1, flexi_MetadataRef_t *r2, int cnt);

/*
 * Compare 2 metadata ref definitions
 * name maybe missing in either one, then comparison by id would be performed
 * It is valid situation when either ref is not initialized (id == 0)
 */
int flexi_metadata_ref_compare(const flexi_MetadataRef_t *r1, const flexi_MetadataRef_t *r2);

struct flexi_class_ref_rule
{
    char *regex;
    flexi_MetadataRef_t classRef;
};

bool flexi_class_ref_rule_compare(const struct flexi_class_ref_rule *p1, const struct flexi_class_ref_rule *p2);

/*
 * Class ref definition type.
 * This type encapsulates info on class reference, including static and dynamic reference
 * Dynamic reference means that actual class type is determines by value in dynSelectorProp property
 * rules define list of regex patterns to be checked again value in dynSelectorProp. First match would define
 * class reference
 */

typedef struct flexi_class_ref_def
{
    flexi_MetadataRef_t classRef;
    flexi_MetadataRef_t dynSelectorProp;

    /*
     * Array of flexi_class_ref_rule
     */
    Array_t rules;
    CHANGE_STATUS eChangeStatus;
    int nRefCount;
} Flexi_ClassRefDef_t;

void flexi_class_ref_def_init(struct flexi_class_ref_def *p);

void flexi_class_ref_def_dispose(struct flexi_class_ref_def *p);

/*
 * Result of comparing 2 class ref definitions
 */
typedef enum ClassRefDef_Compare_Result
{
    /*
     * Both definitions are completely identical
     */
            CLS_REF_DEF_CMP_EQ = 0,

    /*
     * Definions are different
     */
            CLS_REF_DEF_CMP_DIFF = 1,

    /*
     * class and dynPropRef are the same, but second def has more rules
     */
            CLS_REF_DEF_CMP_MORE_RULES = 2,

    /*
     * class and dynPropRef are the same, but second def has less rules
     */
            CLS_REF_DEF_CMP_LESS_RULES = 3
} ClassRefDef_Compare_Result;

/*
 * Compares 2 class ref definitions
 */
ClassRefDef_Compare_Result
flexi_class_ref_def_compare(const struct flexi_class_ref_def *pDef1, const struct flexi_class_ref_def *pDef2);


#endif //CLASS_REF_DEF_H
