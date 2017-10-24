//
// Created by slanska on 2017-10-21.
//

#ifndef FLEXILITE_DUKCONTEXT_H
#define FLEXILITE_DUKCONTEXT_H

#include <duk_config.h>
#include <memory>

#define DUK_OBJECT_REF_PROP_NAME ("\xff""\xff""data")
#define DUK_DELETED_PROP_NAME ("\xff""\xff""deleted")

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

    int test_result(int result);

public:
    explicit DukContext();

    ~DukContext();

    inline duk_context *getCtx()
    {
        return pCtx;
    }

    void test_eval(const char *code);

    int PushObject();

    void PutFunctionList(duk_idx_t obj_idx, const duk_function_list_entry *funcs);

    void SetPrototype(duk_idx_t obj_idx);

    void PutGlobalString(const char *str);

    void PushBoolean(bool v);

    void defineProperty(int objIndex, const char *propName, duk_c_function Getter,
                        duk_c_function Setter = nullptr);

    template<typename T>
    static T *getDukData(duk_context *ctx)
    {
        duk_push_this(ctx);
        duk_get_prop_string(ctx, -1, DUK_OBJECT_REF_PROP_NAME);
        auto result = static_cast<T *>(duk_to_pointer(ctx, -1));
        duk_pop(ctx);
        return result;
    }
};

/*
 * Per-thread instance of Duktape context
 */
extern thread_local std::unique_ptr<DukContext> pDukCtx;

#endif //FLEXILITE_DUKCONTEXT_H
