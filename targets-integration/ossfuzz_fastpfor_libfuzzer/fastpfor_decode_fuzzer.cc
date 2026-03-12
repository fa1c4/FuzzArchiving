// oss-fuzz/projects/fastpfor/fastpfor_decode_fuzzer.cc
#include <cstdint>
#include <cstddef>
#include <vector>
#include <cstring>
#include <stdexcept>

#include "fastpfor.h"
#include "variablebyte.h"

using namespace FastPForLib;

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  if (size < 4) return 0;

  // Interpret fuzz input as a little-endian "compressed uint32 stream"
  const size_t n = size / 4;
  std::vector<uint32_t> comp(n);
  std::memcpy(comp.data(), data, n * 4);

  // Prepare a larger output buffer to avoid internal out-of-bounds writes during decode
  // (Actual out-of-bounds/index errors will be caught by the sanitizer)
  std::vector<uint32_t> out(1u << 16);

  try {
    // Use VariableByte decoding path (more robust for arbitrary lengths)
    {
      VariableByte vb;
      size_t out_n = out.size();
      vb.decodeArray(comp.data(), comp.size(), out.data(), out_n);
    }

    // Use FastPFor decoding path: provide a larger out_n to let internal logic unfold as much as possible
    {
      FastPFor<> fp;
      size_t out_n = out.size();
      fp.decodeArray(comp.data(), comp.size(), out.data(), out_n);
    }
  } catch (const std::exception&) {
    // Do not treat logic exceptions explicitly thrown by the library (invalid format/contract violations) as crashes
  }
  return 0;
}
