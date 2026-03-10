#include <stdint.h>
#include <vector>
#include <algorithm>
#include "fpng.h"

extern "C" int LLVMFuzzerInitialize(int*, char***) {
  fpng::fpng_init(); // Detect SSE capabilities
  return 0;
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  if (!data || size < 1) return 0;

  // Try to get information quickly first (covers parsing paths like fdEC/PNG headers)
  uint32_t w = 0, h = 0, ch = 0;
  (void)fpng::fpng_get_info(data, (uint32_t)std::min<size_t>(size, 0xFFFFFFFFu), w, h, ch);

  // Switch desired_channels between 3/4 to cover both code paths
  uint32_t desired = (data[0] & 1) ? 3u : 4u;

  std::vector<uint8_t> out;
  uint32_t dw=0, dh=0, dch=0;
  (void)fpng::fpng_decode_memory(
      data, (uint32_t)std::min<size_t>(size, 0xFFFFFFFFu),
      out, dw, dh, dch, desired);

  // Note: For non-fpng outputs, it returns FPNG_DECODE_NOT_FPNG; we don't validate this, as long as it doesn't crash.
  return 0;
}
