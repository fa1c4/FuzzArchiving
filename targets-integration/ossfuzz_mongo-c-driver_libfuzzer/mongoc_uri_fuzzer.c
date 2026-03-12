// mongoc_uri_fuzzer.c
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <string.h>

#include <bson/bson.h>
#include <mongoc/mongoc.h>

// Non-public function, defined in mongoc-uri.c; declare it here to link to it
bool mongoc_uri_finalize(mongoc_uri_t *uri, bson_error_t *error);

// Simple helper functions to "assemble int32/int64 from bytes" (avoids UB)
static int32_t bytes_to_i32(const uint8_t *data, size_t size) {
    uint32_t v = 0;
    size_t n = size < 4 ? size : 4;
    for (size_t i = 0; i < n; ++i) {
        v = (v << 8) | (uint32_t)data[i];
    }
    return (int32_t)v;
}

static int64_t bytes_to_i64(const uint8_t *data, size_t size) {
    uint64_t v = 0;
    size_t n = size < 8 ? size : 8;
    for (size_t i = 0; i < n; ++i) {
        v = (v << 8) | (uint64_t)data[i];
    }
    return (int64_t)v;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    static bool initialized = false;
    if (!initialized) {
        mongoc_init();
        initialized = true;
    }

    if (!data || size == 0) {
        return 0;
    }

    // Treat the entire input as a URI string (might be garbage, but that's fine)
    char *uri_str = (char *)bson_malloc(size + 1);
    if (!uri_str) {
        return 0;
    }
    memcpy(uri_str, data, size);
    uri_str[size] = '\0';

    bson_error_t error;
    mongoc_uri_t *uri = mongoc_uri_new_with_error(uri_str, &error);

    // If parsing fails, use a stable fallback URI to continue fuzzing the setter paths
    if (!uri) {
        uri = mongoc_uri_new_with_error("mongodb://127.0.0.1/", &error);
        if (!uri) {
            bson_free(uri_str);
            return 0;
        }
    }

    // Derive some numerical values from the input
    int32_t v32 = bytes_to_i32(data, size);
    int64_t v64 = bytes_to_i64(data, size);
    bool b = (size & 1u) != 0;

    // —— Some representative URI options —— //

    // int32 type
    static const char *kInt32Opts[] = {
        MONGOC_URI_CONNECTTIMEOUTMS,
        MONGOC_URI_HEARTBEATFREQUENCYMS,
        MONGOC_URI_SERVERSELECTIONTIMEOUTMS,
        MONGOC_URI_SOCKETTIMEOUTMS,
        MONGOC_URI_LOCALTHRESHOLDMS,
        MONGOC_URI_MAXPOOLSIZE,
        MONGOC_URI_MAXSTALENESSSECONDS,
        MONGOC_URI_WAITQUEUETIMEOUTMS,
        MONGOC_URI_ZLIBCOMPRESSIONLEVEL,
        MONGOC_URI_SRVMAXHOSTS,
    };

    // int64 type
    static const char *kInt64Opts[] = {
        MONGOC_URI_WTIMEOUTMS,
    };

    // bool type
    static const char *kBoolOpts[] = {
        MONGOC_URI_DIRECTCONNECTION,
        MONGOC_URI_JOURNAL,
        MONGOC_URI_RETRYREADS,
        MONGOC_URI_RETRYWRITES,
        MONGOC_URI_SAFE,
        MONGOC_URI_SERVERSELECTIONTRYONCE,
        MONGOC_URI_TLS,
        MONGOC_URI_TLSINSECURE,
        MONGOC_URI_TLSALLOWINVALIDCERTIFICATES,
        MONGOC_URI_TLSALLOWINVALIDHOSTNAMES,
        MONGOC_URI_TLSDISABLECERTIFICATEREVOCATIONCHECK,
        MONGOC_URI_TLSDISABLEOCSPENDPOINTCHECK,
        MONGOC_URI_LOADBALANCED,
    };

    // utf8 type
    static const char *kUtf8Opts[] = {
        MONGOC_URI_APPNAME,
        MONGOC_URI_REPLICASET,
        MONGOC_URI_READPREFERENCE,
        MONGOC_URI_SERVERMONITORINGMODE,
        MONGOC_URI_SRVSERVICENAME,
        MONGOC_URI_TLSCERTIFICATEKEYFILE,
        MONGOC_URI_TLSCERTIFICATEKEYFILEPASSWORD,
        MONGOC_URI_TLSCAFILE,
    };

    // Assign values to options using fuzz data
    const size_t i32_idx  = data[0] % (sizeof(kInt32Opts) / sizeof(kInt32Opts[0]));
    const size_t i64_idx  = data[0] % (sizeof(kInt64Opts) / sizeof(kInt64Opts[0]));
    const size_t bool_idx = data[0] % (sizeof(kBoolOpts) / sizeof(kBoolOpts[0]));
    const size_t utf8_idx = data[0] % (sizeof(kUtf8Opts) / sizeof(kUtf8Opts[0]));

    (void)mongoc_uri_set_option_as_int32(uri, kInt32Opts[i32_idx], v32);
    (void)mongoc_uri_set_option_as_int64(uri, kInt64Opts[i64_idx], v64);
    (void)mongoc_uri_set_option_as_bool(uri, kBoolOpts[bool_idx], b);
    (void)mongoc_uri_set_option_as_utf8(uri, kUtf8Opts[utf8_idx], uri_str);

    // Also fuzz some other setters along the way
    (void)mongoc_uri_set_username(uri, uri_str);
    (void)mongoc_uri_set_password(uri, uri_str);
    (void)mongoc_uri_set_database(uri, uri_str);
    (void)mongoc_uri_set_auth_source(uri, uri_str);
    (void)mongoc_uri_set_appname(uri, uri_str);
    (void)mongoc_uri_set_compressors(uri, uri_str);
    (void)mongoc_uri_set_server_monitoring_mode(uri, "auto");

    // Finalize again to trigger cross-constraints like TLS / auth / loadBalanced / SRV
    (void)mongoc_uri_finalize(uri, &error);

    // Run through the getters to expand coverage
    (void)mongoc_uri_get_hosts(uri);
    (void)mongoc_uri_get_srv_hostname(uri);
    (void)mongoc_uri_get_srv_service_name(uri);
    (void)mongoc_uri_get_replica_set(uri);
    (void)mongoc_uri_get_string(uri);
    (void)mongoc_uri_get_username(uri);
    (void)mongoc_uri_get_password(uri);
    (void)mongoc_uri_get_database(uri);
    (void)mongoc_uri_get_auth_source(uri);
    (void)mongoc_uri_get_appname(uri);
    (void)mongoc_uri_get_compressors(uri);
    (void)mongoc_uri_get_local_threshold_option(uri);
    (void)mongoc_uri_get_srv_service_name(uri);
    (void)mongoc_uri_get_server_monitoring_mode(uri);
    (void)mongoc_uri_get_tls(uri);

    const mongoc_read_prefs_t *rp = mongoc_uri_get_read_prefs_t(uri);
    if (rp) {
        (void)mongoc_read_prefs_is_valid(rp);
    }

    const mongoc_read_concern_t *rc = mongoc_uri_get_read_concern(uri);
    if (rc) {
        (void)mongoc_read_concern_get_level(rc);
    }

    const mongoc_write_concern_t *wc = mongoc_uri_get_write_concern(uri);
    if (wc) {
        (void)mongoc_write_concern_get_w(wc);
    }

    // Copy and then destroy to cover the copy path
    mongoc_uri_t *copy = mongoc_uri_copy(uri);
    if (copy) {
        mongoc_uri_destroy(copy);
    }

    mongoc_uri_destroy(uri);
    bson_free(uri_str);
    return 0;
}
