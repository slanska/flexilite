//
// Created by slanska on 2017-10-21.
//

#include <duk_config.h>
#include <sqlite3ext.h>

SQLITE_EXTENSION_INIT3

void SQLiteValuesToDukStack(duk_context *ctx, int argc, sqlite3_value **argv)
{
    int ii;
    for (ii = 0; ii < argc; ii++)
    {
        int tt = sqlite3_value_type(argv[ii]);
        switch (tt)
        {
            case SQLITE_INTEGER :
                break;
            case SQLITE_FLOAT    :
                break;
            case SQLITE_BLOB     :
                break;
            case SQLITE_NULL     :
                break;
            case SQLITE_TEXT:
                break;

            default:
                break;

        }
    }
}
