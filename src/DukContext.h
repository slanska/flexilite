//
// Created by slanska on 2017-10-21.
//

#ifndef FLEXILITE_DUKCONTEXT_H
#define FLEXILITE_DUKCONTEXT_H

#include <duk_config.h>
#include <memory>

/*
 * Duktape context holder, per thread.
 * Provides following:
 * 1) keeps Duktape heap and context (using sqlite memory API), with possible multiple SQLite databases opened
 * (assuming that every database connection gets always opened and operated in the same thread)
 * 2) Register SQLite wrapper objects (Database, Statement etc.) in Duktape
 * 3) Loads and initializes flexilite JS bundle (one bundle per thread, not per connection)
 * 4) Cleans up all allocated resources on thread exit
 */
class DukContext
{
private:
    duk_context *pCtx;
public:
    explicit DukContext();

    ~DukContext();

    inline duk_context *getCtx()
    {
        return pCtx;
    }

    void test_eval(const char *code);
};

extern thread_local std::unique_ptr<DukContext> pDukCtx;

#endif //FLEXILITE_DUKCONTEXT_H
