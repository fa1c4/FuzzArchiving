// fuzz_ws_decode.c
// LLVM libFuzzer harness for TurboVNC's WebSocket frame decoder
//
// Goal: Fuzz webSocketsDecodeHybi(ws_ctx_t*, char*, int) directly.
// Uses ws_ctx_t->ctxInfo.readFunc to read data from the fuzzer input "pseudo-socket".

#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <stdarg.h>

/*
 * Minimal declarations for internal Xorg/Xvnc types used in rfb.h 
 * to avoid including the entire X server header tree.
 *
 * In the Xorg source, these typedefs are roughly:
 * typedef struct _RROutput *RROutputPtr;
 * typedef struct _Property *PropertyPtr;
 */
typedef struct _RROutput *RROutputPtr;
typedef struct _Property *PropertyPtr;

#include "ws_decode.h"   // Provides declarations for ws_ctx_t / webSocketsDecodeHybi / hybiDecodeCleanupComplete, etc.

// ================= Global Fuzzer Input Buffer =================

static const uint8_t *g_data = NULL;
static size_t g_size = 0;
static size_t g_off  = 0;

// Read data from fuzzer input (simulating a low-level socket read)
static int fuzz_ws_read(void *ctxPtr, char *buf, size_t len) {
    (void)ctxPtr;  // We don't need this parameter

    if (len == 0)
        return 0;

    if (g_off >= g_size)
        // Simulate peer closure: return 0, which ws_decode will handle
        return 0;

    size_t remaining = g_size - g_off;
    if (len > remaining)
        len = remaining;

    memcpy(buf, g_data + g_off, len);
    g_off += len;

    // In ws_decode, the return value is treated as a recv() return value: 
    // >0 is normal, 0 = peer closed, <0 = error
    return (int)len;
}

// ================== rfbLog stub ==================
// ws_decode.c uses rfbLog(...); we provide a dummy implementation here 
// so we don't need to link the entire rfb logging system.
//
// Note: The signature must match unix/Xvnc/programs/Xserver/hw/vnc/rfb.h:
//   extern void rfbLog(char *format, ...);

void rfbLog(char *format, ...) {
    (void)format;
    // Discard logs to avoid affecting performance
}

// ================= libFuzzer Entry Point =================

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (size == 0)
        return 0;

    g_data = data;
    g_size = size;
    g_off  = 0;

    // Allocate ws_ctx_t (defined in ws_decode.h)
    ws_ctx_t *wsctx = (ws_ctx_t *)calloc(1, sizeof(ws_ctx_t));
    if (!wsctx)
        return 0;

    // Reset internal state using the initialization function provided by ws_decode
    hybiDecodeCleanupComplete(wsctx);

    // Set the "pseudo-socket read" callback
    wsctx->ctxInfo.readFunc = fuzz_ws_read;
    wsctx->ctxInfo.ctxPtr   = NULL;   // Our fuzz_ws_read doesn't care about this

    // Output buffer (decoded payload will be written here)
    char out[1024];

    // To drive more state transitions, call webSocketsDecodeHybi multiple times.
    for (int i = 0; i < 4; i++) {
        errno = 0;
        int n = webSocketsDecodeHybi(wsctx, out, (int)sizeof(out));

        if (n <= 0) {
            // n < 0: Error (including EAGAIN / EPROTO / ECONNRESET / EIO, etc.)
            // n == 0: No valid data returned; simply stop this fuzz call
            break;
        }

        // n > 0: Successfully obtained some decoded payload data.
        // We don't care about the content itself, only about covering the parsing logic.
    }

    free(wsctx);
    return 0;
}
