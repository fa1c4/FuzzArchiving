// OSS-Fuzz libFuzzer harness for ngrep.
//
// Strategy:
//   Input layout:
//     - First 64 bytes  -> "pattern" (what a user might pass to ngrep on CLI,
//                           i.e. regex or hex expression).
//     - Remaining bytes -> "captured packet" payload.
//
//   We call two helpers that ngrep (or our shim) provides:
//     int ngrep_compile_pattern(const char *expr);
//     int ngrep_process_packet(const uint8_t *buf, size_t len);
//
//   Long-term plan:
//     - Refactor ngrep.c so its real regex compile path and packet dump/
//       parsing path live in reusable helpers with those exact names.
//     - Delete the stub shim in build.sh once that happens.

#include <stdint.h>
#include <stddef.h>
#include <string.h>

int ngrep_compile_pattern(const char *expr);
int ngrep_process_packet(const uint8_t *buf, size_t len);

// Extract up to 64 bytes from fuzzer input as a printable, NUL-terminated
// pattern string. Replace embedded NUL with '.' so we always pass a single
// contiguous C-string to ngrep_compile_pattern().
static void extract_pattern(const uint8_t *data, size_t size,
                            char *out_pat, size_t out_cap) {
    size_t pat_len = 0;
    const size_t max_pat = (out_cap - 1 < 64) ? (out_cap - 1) : 64;

    while (pat_len < max_pat && pat_len < size) {
        char c = (char)data[pat_len];
        if (c == '\0') c = '.';
        out_pat[pat_len++] = c;
    }
    out_pat[pat_len] = '\0';

    if (pat_len == 0) {
        // Fallback so we always compile *something* non-empty.
        strcpy(out_pat, "GET|POST");
    }
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    // 1. Pattern compilation path (PCRE2 etc.)
    char pattern[128];
    extract_pattern(data, size, pattern, sizeof(pattern));
    (void)ngrep_compile_pattern(pattern);

    // 2. Packet inspection / printing path
    if (size > 64) {
        const uint8_t *payload = data + 64;
        size_t payload_len = size - 64;
        (void)ngrep_process_packet(payload, payload_len);
    }

    return 0;
}
