//
// Created by slanska on 2017-01-23.
//

#include <stdio.h>
#include "file_helper.h"

int file_load_utf8(const char *zFileName, char **ppBuf) {
    int result = SQLITE_OK;
    *ppBuf = NULL;
    size_t length;
    FILE *f = fopen(zFileName, "rb");

    if (f) {
        fseek(f, 0, SEEK_END);
        length = (size_t) ftell(f);
        fseek(f, 0, SEEK_SET);
        CHECK_MALLOC(*ppBuf, (int) length + 1);
        fread(*ppBuf, 1, length, f);
        (*ppBuf)[length] = 0;

        fclose(f);
    }

    goto FINALLY;

    CATCH:
    sqlite3_free(*ppBuf);

    FINALLY:
    return result;
}
