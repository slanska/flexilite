//
// Created by slanska on 2017-02-26.
//

#ifndef CLASS_REF_DEF_H
#define CLASS_REF_DEF_H

#include <stdbool.h>
#include "../util/buffer.h"

/*
 * Holds entity name and corresponding ID
 * Used for user-friendly way of specifying classes, properties, enums, names.
 * Holder of this struct is responsible for freeing name
 */
struct flexi_metadata_ref
{
    char *name;
    sqlite3_int64 id;

    enum CHANGE_STATUS eChngStatus;
    bool bOwnName;
};

typedef struct flexi_metadata_ref flexi_metadata_ref;

void flexi_metadata_ref_free(flexi_metadata_ref *);

/*
 * Compare 2 metadata ref definitions
 * name maybe missing in either one, then comparison by id would be performed
 * It is valid situation when either ref is not initialized (id == 0)
 */
bool flexi_metadata_ref_compare(const flexi_metadata_ref *r1, const flexi_metadata_ref *r2);

struct flexi_class_ref_rule
{
    char *regex;
    flexi_metadata_ref classRef;
};

bool flexi_class_ref_rule_compare(const struct flexi_class_ref_rule* p1, const struct flexi_class_ref_rule* p2);

/*
 * Class ref definition type.
 * This type encapsulates info on class reference, including static and dynamic reference
 * Dynamic reference means that actual class type is determines by value in dynSelectorProp property
 * rules define list of regex patterns to be checked again value in dynSelectorProp. First match would define
 * class reference
 */

typedef struct flexi_class_ref_def
{
    flexi_metadata_ref classRef;
    flexi_metadata_ref dynSelectorProp;

    /*
     * Array of flexi_class_ref_rule
     */
    Buffer rules;
    CHANGE_STATUS eChangeStatus;
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
