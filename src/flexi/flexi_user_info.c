//
// Created by slanska on 2017-02-19.
//

#include "flexi_user_info.h"

void flexi_free_user_info(struct flexi_user_info *p)
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

