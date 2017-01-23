//
// Created by slanska on 2017-01-23.
//

#include <stdio.h>
#include "file_helper.h"
#include "../../src/project_defs.h"

int file_load(const char *zFileName, void **ppBuf) {
    int result = SQLITE_OK;
    *ppBuf = 0;
    size_t length;
    FILE *f = fopen(zFileName, "rb");

    if (f) {
        fseek(f, 0, SEEK_END);
        length = (size_t)ftell(f);
        fseek(f, 0, SEEK_SET);
        *ppBuf = CHECK_MALLOC(*ppBuf, length);
        if (*ppBuf) {
            fread(*ppBuf, 1, length, f);
        }
        fclose(f);
    }

    goto FINALLY;

    CATCH:

    FINALLY:
    return result;
}
