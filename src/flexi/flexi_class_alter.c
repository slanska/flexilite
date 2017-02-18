//
// Created by slanska on 2016-04-23.
//

/*
 * Implementation of class alteration
 */

#include "../project_defs.h"

/*
 * Generic function to alter class definition
 * Performs all validations and necessary data updates
 */
void flexi_class_alter(
        const char *zClassName,
        const char *zNewClassDefJson
) {

}

/*
 * Internal function to create new or alter existing class
 */
void flexi_class_create_or_alter(
        struct flexi_db_context *pCtx,
        const char *zClassName,
        const char *zNewClassDefJson,
        int bCreate,
        int bAsTable
) {

}

