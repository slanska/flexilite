//
// Created by slanska on 2017-02-12.
//

#ifndef FLEXILITE_FLEXI_CLASS_H
#define FLEXILITE_FLEXI_CLASS_H

int flexi_class_create(sqlite3 *db,
        // User data
                       void *pAux,
                       const char *zClassName,
                       const char *zClassDef,
                       int bCreateVTable,
                       char **pzError);

#endif //FLEXILITE_FLEXI_CLASS_H
