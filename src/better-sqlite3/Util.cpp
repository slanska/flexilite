//
// Created by slanska on 2017-10-21.
//

#include "Util.h"

DukValue DukValues::get(std::string key)
{
    return _values[key];
}

void DukValues::set(std::string key, DukValue value)
{
    _values[key] = value;
}

void DefineDuktapeProperty(duk_context *ctx, int objIndex, const char *propName, duk_c_function Getter,
                           duk_c_function Setter)
{
    uint flags = 0;
    duk_push_string(ctx, propName);
    if (Getter)
    {
        duk_push_c_function(ctx, Getter, 0);
        flags |= DUK_DEFPROP_HAVE_GETTER;
    }
    if (Setter)
    {
        duk_push_c_function(ctx, Setter, 0);
        flags |= DUK_DEFPROP_HAVE_SETTER;
    }
    duk_def_prop(ctx, objIndex, flags);
}
