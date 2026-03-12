#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#include <bson/bson.h>
#include <mongoc/mongoc.h>

// Non-public function, defined in mongoc-read-prefs.c; declared here
bool _mongoc_read_prefs_validate(const mongoc_read_prefs_t *read_prefs, bson_error_t *error);

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (!data || size == 0) {
        return 0;
    }

    static const mongoc_read_mode_t kModes[] = {
        MONGOC_READ_PRIMARY,
        MONGOC_READ_SECONDARY,
        MONGOC_READ_PRIMARY_PREFERRED,
        MONGOC_READ_SECONDARY_PREFERRED,
        MONGOC_READ_NEAREST,
    };
    mongoc_read_mode_t mode = kModes[data[0] % (sizeof(kModes) / sizeof(kModes[0]))];

    mongoc_read_prefs_t *rp = mongoc_read_prefs_new(mode);
    if (!rp) {
        return 0;
    }

    int64_t max_staleness = 0;
    size_t n = size < 9 ? size : 9;
    for (size_t i = 1; i < n; ++i) {
        max_staleness = (max_staleness << 8) | (int64_t)data[i];
    }
    mongoc_read_prefs_set_max_staleness_seconds(rp, max_staleness);

    bson_t *doc = NULL;
    if (size >= 4) {
        doc = bson_new_from_data(data, size);
    }

    if (doc) {
        mongoc_read_prefs_set_tags(rp, doc);
        mongoc_read_prefs_add_tag(rp, doc);
        mongoc_read_prefs_set_hedge(rp, doc);
    } else {
        mongoc_read_prefs_set_tags(rp, NULL);
        mongoc_read_prefs_set_hedge(rp, NULL);
    }

    (void)mongoc_read_prefs_get_mode(rp);
    (void)mongoc_read_prefs_get_tags(rp);
    (void)mongoc_read_prefs_get_max_staleness_seconds(rp);
    // Removed mlib_diagnostic_* macros here, just call it directly
    (void)mongoc_read_prefs_get_hedge(rp);

    (void)mongoc_read_prefs_is_valid(rp);

    bson_error_t error;
    (void)_mongoc_read_prefs_validate(rp, &error);

    if (doc) {
        bson_destroy(doc);
    }
    mongoc_read_prefs_destroy(rp);
    return 0;
}
