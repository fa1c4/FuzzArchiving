// fuzz_epoxy_extension_in_string.c
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "epoxy/common.h"

/*
 * Fuzz target:
 *
 * bool epoxy_extension_in_string(const char *extension_list,
 * const char *ext);
 *
 * This is a pure string manipulation function that does not depend on any 
 * GL/EGL context, making it ideal for running in a headless OSS-Fuzz environment.
 */

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    // Must have at least 2 bytes to be meaningful, otherwise return immediately
    if (size < 2)
        return 0;

    // Split the input in half: the first part as extension_list, the second part as ext
    size_t split = size / 2;
    size_t list_len = split;
    size_t ext_len  = size - split;

    char *extension_list = (char *)malloc(list_len + 1);
    char *ext            = (char *)malloc(ext_len + 1);

    if (!extension_list || !ext) {
        free(extension_list);
        free(ext);
        return 0;
    }

    memcpy(extension_list, data, list_len);
    extension_list[list_len] = '\0';

    memcpy(ext, data + split, ext_len);
    ext[ext_len] = '\0';

    // Only perform the call; the return value is ignored.
    // Leave it to the sanitizer and libFuzzer to catch any issues.
    (void)epoxy_extension_in_string(extension_list, ext);

    free(extension_list);
    free(ext);
    return 0;
}
