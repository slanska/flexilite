#include <stdio.h>

#include <sqlite3ext.h>
#include <json.h>

SQLITE_EXTENSION_INIT3


void json_extract_func(sqlite3_context *ctx, int argc, sqlite3_value **argv) {
    struct json_tokener *tok = sqlite3_user_data(ctx);
    struct json_object *root_obj, *obj;
    enum json_tokener_error jerr;
    int i, idx, missing = 0;

    if (argc < 1) {
        // What is -1?  It seems to always be used and the docs did not explain.
        sqlite3_result_error(ctx, "no data", -1);
        return;
    }

    if (sqlite3_value_text(argv[0]) == NULL) {
        sqlite3_result_null(ctx);
        return;
    }

    root_obj = json_tokener_parse_ex(tok, (const char *)sqlite3_value_text(argv[0]), sqlite3_value_bytes(argv[0])+1);
    if ((jerr = json_tokener_get_error(tok)) != json_tokener_success) {
        sqlite3_result_error(ctx, json_tokener_error_desc(jerr), -1);
        json_tokener_reset(tok);
        return;
    }

    // TODO: How to get a raw value?  Is it another function?
    for (obj = root_obj, i = 1; i < argc && obj != NULL && !json_object_is_type(obj, json_type_null); i++) {
        switch (json_object_get_type(obj)) {
            case json_type_array:
                idx = sqlite3_value_int(argv[i]);
                if (idx < 0) {
                    idx += json_object_array_length(obj);
                    missing = idx < 0;
                } else {
                    missing = idx >= json_object_array_length(obj);
                }
                obj = json_object_array_get_idx(obj, idx);
                break;

            case json_type_object:
                missing = !json_object_object_get_ex(obj, (const char *)sqlite3_value_text(argv[i]), &obj);
                break;

            default:
                obj = NULL;
                break;
        }

        //printf("[%d=%s]: %p type is %s\n", i, sqlite3_value_text(argv[i]), obj, json_type_to_name(json_object_get_type(obj)));
    }

    if (missing)
        sqlite3_result_null(ctx);

    else
        // The json string buffer is associated with the object, which we are
        // about to free.  The TRANSIENT flag instructs sqlite to make a copy.
        sqlite3_result_text(ctx, json_object_to_json_string_ext(obj, JSON_C_TO_STRING_PLAIN), -1, SQLITE_TRANSIENT);

    // TODO: Confirm that only the root needs to be derefed.
    // NOTE: put/get here refer to reference counting.
    json_object_put(root_obj);
    json_tokener_reset(tok);
}


void json_unquote_func(sqlite3_context *ctx, int argc, sqlite3_value **argv) {
    struct json_tokener *tok = sqlite3_user_data(ctx);
    struct json_object *obj;
    enum json_tokener_error jerr;

    if (sqlite3_value_text(argv[0]) == NULL) {
        sqlite3_result_null(ctx);
        return;
    }

    obj = json_tokener_parse_ex(tok, (const char *)sqlite3_value_text(argv[0]), sqlite3_value_bytes(argv[0])+1);
    if ((jerr = json_tokener_get_error(tok)) != json_tokener_success) {
        sqlite3_result_error(ctx, json_tokener_error_desc(jerr), -1);
        json_tokener_reset(tok);
        return;
    }

    switch (json_object_get_type(obj)) {
        case json_type_null:
            sqlite3_result_null(ctx);
            break;

        case json_type_boolean:
            sqlite3_result_int(ctx, json_object_get_boolean(obj));
            break;

        case json_type_int:
            sqlite3_result_int64(ctx, json_object_get_int64(obj));
            break;

        case json_type_double:
            sqlite3_result_double(ctx, json_object_get_double(obj));
            break;

        case json_type_string:
            sqlite3_result_text(ctx, json_object_get_string(obj), json_object_get_string_len(obj), SQLITE_TRANSIENT);
            break;

        default:
            sqlite3_result_error(ctx, "cannot unquote object or array", -1);
            break;
    }

    json_object_put(obj);
    json_tokener_reset(tok);
}
