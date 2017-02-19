//
// Created by slanska on 2017-02-19.
//

#ifndef FLEXILITE_FLEXI_USER_INFO_H
#define FLEXILITE_FLEXI_USER_INFO_H

#include <sqlite3ext.h>

SQLITE_EXTENSION_INIT3

typedef struct flexi_user_info flexi_user_info;

/*
 * Container for user ID and roles
 */
struct flexi_user_info {
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

void flexi_free_user_info(struct flexi_user_info *p);

#endif //FLEXILITE_FLEXI_USER_INFO_H
