//
// Created by slanska on 2017-10-21.
//

#ifndef FLEXILITE_UTIL_H
#define FLEXILITE_UTIL_H

#include <cstdint>
#include <string>
#include <dukglue.h>
#include <map>

#define DUK_OBJECT_REF_PROP_NAME "\xff""\xff""data"
#define DUK_DELETED_PROP_NAME "\xff""\xff""deleted"

/*
 * Counterpart to better=sqlite4 RunResult interface
 */
class RunResult
{
public:
    int64_t changes;
    int64_t lastInsertROWID;
};

/*
 *
 */
class DukValues
{
private:
    std::map<std::string, DukValue> _values = {};
public:
    DukValue get(std::string key);

    void set(std::string key, DukValue value);
};

void DefineDuktapeProperty(duk_context *ctx, int objIndex, const char *propName, duk_c_function Getter,
                           duk_c_function Setter = nullptr);

template<typename T>
T *getDukData(duk_context *ctx)
{
    duk_push_this(ctx);
    duk_get_prop_string(ctx, -1, DUK_OBJECT_REF_PROP_NAME);
    auto result = static_cast<T *>(duk_to_pointer(ctx, -1));
    duk_pop(ctx);
    return result;
}

#endif //FLEXILITE_UTIL_H
