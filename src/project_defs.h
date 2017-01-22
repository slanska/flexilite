//
// Created by slanska on 2017-01-22.
//

/*
 * Project internal definitions
 */

#ifdef __SOME__

#include "../lib/sqlite/sqlite3ext.h"

SQLITE_EXTENSION_INIT3

#include <assert.h>
#include <string.h>
#include <ctype.h>
#include <alloca.h>
#include <stdio.h>

#include "./misc/json1.h"
#include "./flexi/flexi_eav.h"
#include "./typings/DBDefinitions.h"
#include "./util/hash.h"
#include "./flexi/flexi_eav.h"
#include "./misc/regexp.h"
#include "./fts/fts3Int.h"

#ifndef SQLITE_EXTENSIONS_PROJECT_DEFS_H
#define SQLITE_EXTENSIONS_PROJECT_DEFS_H

#endif //SQLITE_EXTENSIONS_PROJECT_DEFS_H

#endif