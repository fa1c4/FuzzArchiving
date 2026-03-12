#include <stddef.h>
#include <stdint.h>
#include <bson/bson.h>

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (size < 5) {
        return 0;
    }

    bson_t *doc = bson_new_from_data(data, size);
    if (!doc) {
        return 0;
    }

    bson_iter_t iter;
    if (bson_iter_init(&iter, doc)) {
        while (bson_iter_next(&iter)) {
            const char *key = bson_iter_key(&iter);
            (void)key;

            bson_type_t t = bson_iter_type(&iter);
            switch (t) {
                case BSON_TYPE_UTF8: {
                    uint32_t len = 0;
                    const char *str = bson_iter_utf8(&iter, &len);
                    (void)str;
                    (void)len;
                    break;
                }
                case BSON_TYPE_INT32:
                    (void)bson_iter_int32(&iter);
                    break;
                case BSON_TYPE_INT64:
                    (void)bson_iter_int64(&iter);
                    break;
                case BSON_TYPE_DOUBLE:
                    (void)bson_iter_double(&iter);
                    break;
                case BSON_TYPE_DOCUMENT:
                case BSON_TYPE_ARRAY: {
                    bson_iter_t child;
                    if (bson_iter_recurse(&iter, &child)) {
                        while (bson_iter_next(&child)) {
                            (void)bson_iter_key(&child);
                        }
                    }
                    break;
                }
                default:
                    break;
            }
        }
    }

    char *json = bson_as_canonical_extended_json(doc, NULL);
    if (json) {
        bson_free(json);
    }

    bson_destroy(doc);
    return 0;
}
