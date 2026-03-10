// oss-fuzz/projects/nemesis/fuzz_print.c
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

#include "nemesis.h"

// Clamp to a sane upper bound to avoid excessive stdout spam on long inputs.
static size_t clamp_len(size_t n) {
  const size_t kMax = 1u << 20; // 1 MiB is plenty for a print path
  return n > kMax ? kMax : n;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (!data || size == 0) return 0;

  size_t len = clamp_len(size);
  uint8_t *buf = (uint8_t *)malloc(len);
  if (!buf) return 0;

  memcpy(buf, data, len);

  // nemesis_hexdump(uint8_t *buf, uint32_t len, int mode)
  // Passing 0 uses the most basic dump format; 
  // Keep compatible if format indices change between versions.
  nemesis_hexdump(buf, (uint32_t)len, 0);

  free(buf);
  return 0;
}
