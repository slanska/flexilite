//
// Created by slanska on 2017-02-19.
//

#ifndef FLEXILITE_FLEXI_USER_INFO_H
#define FLEXILITE_FLEXI_USER_INFO_H

#include <sqlite3ext.h>

SQLITE_EXTENSION_INIT3

typedef struct flexi_UserInfo_t flexi_UserInfo_t;

/*
 * Container for user ID and roles
 */
struct flexi_UserInfo_t
{
    /*
     * User ID
     */
    sqlite3_value *vUserID;

    /*
     * List of roles
     */
    char **zRoles;

    /*
     * Number of roles
     */
    int nRoles;

    /*
     * Current culture
     */
    char *zCulture;
};

void flexi_UserInfo_free(struct flexi_UserInfo_t *p);

int flexi_UserInfo_parse(struct flexi_UserInfo_t *self, const char *zData, char **pzErr);

struct flexi_UserInfo_t *flexi_UserInfo_parseNew(const char *zData, char **pzErr);

#endif //FLEXILITE_FLEXI_USER_INFO_H
