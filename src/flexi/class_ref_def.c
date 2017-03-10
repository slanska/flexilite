//
// Created by slanska on 2017-02-26.
//

#include <sqlite3ext.h>
#include <string.h>
#include <stdlib.h>
#include "class_ref_def.h"

SQLITE_EXTENSION_INIT3

void flexi_metadata_ref_free(flexi_metadata_ref *pp)
{
    if (pp && pp->bOwnName)
        sqlite3_free(pp->name);
}

void flexi_class_ref_def_dispose(struct flexi_class_ref_def *p)
{
    if (p)
    {
        Array_clear(&p->rules);
        sqlite3_free(p->classRef.name);
        sqlite3_free(p->dynSelectorProp.name);
    }
}

static void _disposeMixinRuleItem(struct flexi_class_ref_rule *rr)
{
    sqlite3_free(rr->classRef.name);
    sqlite3_free(rr->regex);
}

void flexi_class_ref_def_init(struct flexi_class_ref_def *p)
{
    memset(p, 0, sizeof(*p));
    Array_init(&p->rules, sizeof(struct flexi_class_ref_rule), (void *) _disposeMixinRuleItem);
}

static void
_compareRefRules(const char *zUnused, u32 idx, const struct flexi_class_ref_rule *item, Array_t *pBuf, Array_t *pBuf2,
                 bool *bStop)
{
    UNUSED_PARAM(zUnused);
    const struct flexi_class_ref_rule *pItem2;
    pItem2 = Array_getNth(pBuf2, idx);
    if (!flexi_class_ref_rule_compare(item, pItem2))
    {
        *bStop = true;
    }
}

ClassRefDef_Compare_Result
flexi_class_ref_def_compare(const struct flexi_class_ref_def *pDef1, const struct flexi_class_ref_def *pDef2)
{
    if (flexi_metadata_ref_compare(&pDef1->classRef, &pDef2->classRef) != 0 &
        flexi_metadata_ref_compare(&pDef1->dynSelectorProp, &pDef2->dynSelectorProp) != 0)
        return CLS_REF_DEF_CMP_DIFF;

    ClassRefDef_Compare_Result result;

    // Compare rules
    int nDiff = pDef1->rules.iCnt - pDef2->rules.iCnt;
    const Array_t *buf;
    const Array_t *buf2;
    if (nDiff < 0)
    {
        result = CLS_REF_DEF_CMP_LESS_RULES;
        buf = &pDef1->rules;
        buf2 = &pDef2->rules;
    }
    else
    {
        result = CLS_REF_DEF_CMP_MORE_RULES;
        buf = &pDef2->rules;
        buf2 = &pDef1->rules;
    }

    if (Array_each(buf, (void *) _compareRefRules, (var) buf2))
        return CLS_REF_DEF_CMP_DIFF;

    return result;
}

int flexi_metadata_ref_compare(const flexi_metadata_ref *r1, const flexi_metadata_ref *r2)
{
    if (r1->name && r2->name)
    {
        return sqlite3_stricmp(r1->name, r2->name) == 0;
    }

    sqlite3_int64 diff = r1->id - r2->id;
    return diff > 0 ? 1 : (diff < 0 ? -1 : 0);
}

bool flexi_class_ref_rule_compare(const struct flexi_class_ref_rule *p1, const struct flexi_class_ref_rule *p2)
{
    int result = strcmp(p1->regex, p2->regex);
    if (result == 0)
    {
        return flexi_metadata_ref_compare(&p1->classRef, &p2->classRef) == 0;
    }

    return false;
}

bool flexi_metadata_ref_compare_n(flexi_metadata_ref *r1, flexi_metadata_ref *r2, int cnt)
{
    int found = 0;
    qsort(r1, (size_t) cnt, sizeof(*r1), (void *) flexi_metadata_ref_compare);
    for (int ii = 0; ii < cnt; ii++)
    {
        if (bsearch((const void *) &r2[ii], r1, (size_t) cnt, sizeof(*r1),
                    (void *) flexi_metadata_ref_compare))
        {
            found++;
        }
    }

    return found == cnt;
}




