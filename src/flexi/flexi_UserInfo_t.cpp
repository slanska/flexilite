//
// Created by slanska on 2017-02-19.
//

#include <stddef.h>
#include "flexi_UserInfo_t.h"

void flexi_UserInfo_free(struct flexi_UserInfo_t *p)
{
    if (p)
    {
        sqlite3_value_free(p->vUserID);
        sqlite3_free(p->zCulture);
        for (int ii = 0; ii < p->nRoles; ii++)
        {
            sqlite3_free(p->zRoles[ii]);
        }
        sqlite3_free(p->zRoles);
        sqlite3_free(p);
    }
}

int flexi_UserInfo_parse(struct flexi_UserInfo_t *self, const char *zData, char **pzErr)
{
    //TODO
    return 0;
}

struct flexi_UserInfo_t *flexi_UserInfo_parseNew(const char *zData, char **pzErr)
{
    //TODO
    return NULL;
}



