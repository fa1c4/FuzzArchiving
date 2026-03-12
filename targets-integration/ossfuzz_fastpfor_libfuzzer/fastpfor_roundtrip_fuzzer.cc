// oss-fuzz/projects/fastpfor/fastpfor_roundtrip_fuzzer.cc
#include <cstdint>
#include <cstddef>
#include <vector>
#include <cstring>
#include <algorithm>

// FastPFOR headers (replace as needed if your fork has a different name)
#include "fastpfor.h"
#include "variablebyte.h"
#include <stdexcept>
// Optional: Can also try Simple8b / BP32, etc., if headers are available: #include "simple8b.h" / "bp32.h"

using namespace FastPForLib;

static inline void to_uint32_vec(const uint8_t* data, size_t size,
                                 std::vector<uint32_t>& out) {
  const size_t n = size / 4;
  out.resize(n);
  // Copy directly using little-endian
  std::memcpy(out.data(), data, n * 4);
}

// To avoid investigating out-of-bounds code, reserve ample output buffer: 4x + 1k
static inline size_t safe_compressed_cap(size_t in_n) {
  const size_t base = in_n * 4 + 1024;
  // Prevent extreme big inputs from exploding in memory
  return std::min(base, static_cast<size_t>(1 << 26)); // ≤ ~256 Mi uint32
}

static inline void safe_roundtrip(IntegerCODEC& codec,
                                  const std::vector<uint32_t>& src) {
  try {
    if (src.empty()) return;

    std::vector<uint32_t> comp(src.size() * 4 + 1024);
    size_t comp_n = comp.size();
    codec.encodeArray(src.data(), src.size(), comp.data(), comp_n);
    comp.resize(comp_n);

    std::vector<uint32_t> rec(src.size() + 1024);
    size_t rec_n = rec.size();
    codec.decodeArray(comp.data(), comp.size(), rec.data(), rec_n);

    // Must be exactly identical, otherwise considered not equivalent (trigger a crash for the fuzzer coverage to see)
    if (rec_n != src.size() ||
        std::memcmp(src.data(), rec.data(), src.size() * sizeof(uint32_t)) != 0) {
      __builtin_trap();
    }
  } catch (const std::logic_error&) {
    // Codecs like FastPFor might throw exceptions directly due to preconditions like "length not block-aligned";
    // Such inputs are "unsupported" by the library and are not crash signals for fuzzing: just ignore them
  } catch (const std::exception&) {
    // Ignore other exceptions as well (if you want to treat exceptions as bugs, you can delete this catch block)
  }
}

// ★ Added: Pad the sequence to a multiple of m (for FastPFor block alignment)
static inline std::vector<uint32_t> pad_to_multiple(const std::vector<uint32_t>& v, size_t m) {
  if (v.empty()) return v;
  size_t n = ((v.size() + m - 1) / m) * m;
  std::vector<uint32_t> out = v;
  out.resize(n, v.back()); // Pad the tail with the last value to avoid introducing outrageous distributions
  return out;
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  if (size < 4) return 0;

  const size_t max_elems = 1u << 15; // 32768
  const size_t n = std::min(size / 4, max_elems);

  std::vector<uint32_t> a;
  a.resize(n);
  std::memcpy(a.data(), data, n * 4);

  std::vector<uint32_t> small(a.begin(), a.end());
  for (auto& x : small) x &= 0x3FFu;

  std::vector<uint32_t> mono(a.begin(), a.end());
  for (size_t i = 1; i < mono.size(); ++i) mono[i] += mono[i - 1];

  VariableByte vb;
  FastPFor<>   fp;

  // 1) Run VariableByte for any length (handles small arrays / unaligned)
  safe_roundtrip(vb, a);
  safe_roundtrip(vb, small);
  safe_roundtrip(vb, mono);

  // 2) Run FastPFor only on "block-aligned" versions to avoid throwing exceptions and interrupting fuzzing
  //    Empirically FastPFor uses 128/256 granularity; using 256 is more conservative
  auto a_pad     = pad_to_multiple(a,    256);
  auto small_pad = pad_to_multiple(small,256);
  auto mono_pad  = pad_to_multiple(mono, 256);

  safe_roundtrip(fp, a_pad);
  safe_roundtrip(fp, small_pad);
  safe_roundtrip(fp, mono_pad);
  return 0;
}
