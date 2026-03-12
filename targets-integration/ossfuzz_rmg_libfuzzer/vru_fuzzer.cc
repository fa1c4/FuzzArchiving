// oss-fuzz/projects/rmg/vru_fuzzer.cc
#include <cstdint>
#include <vector>

#include "VRU.hpp"
#include <RMG-Core/m64p/api/m64p_types.h>

// m64p's CALL macro comes from m64p_types.h
extern "C" {

// VRU plugin exported functions are defined in VRU.cpp with EXPORT + CALL,
// Just do a forward declaration here.
void CALL SendVRUWord(uint16_t length, uint16_t *word, uint8_t lang);
void CALL ReadVRUResults(uint16_t *error_flags,
                         uint16_t *num_results,
                         uint16_t *mic_level,
                         uint16_t *voice_level,
                         uint16_t *voice_length,
                         uint16_t *matches);
void CALL ClearVRUWords(uint8_t length);
void CALL SetMicState(int state);
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (size < 4) return 0;

  static bool initialized = false;
  if (!initialized) {
    // If InitVRU() fails here due to missing resources,
    // this fuzzer becomes a no-op in the current process.
    if (!InitVRU()) {
      return 0;
    }
    initialized = true;
  }

  // The first byte determines the word list length (max 32)
  uint8_t wordCount = data[0] % 32;
  if (wordCount == 0) return 0;

  // The second byte: mic toggle
  SetMicState(data[1] & 1);

  // Initialize the VRU word list
  ClearVRUWords(wordCount);

  // Pack the remaining data into several uint16_t "words"
  std::vector<uint16_t> words(wordCount);
  const uint8_t *p = data + 2;
  size_t remaining = size - 2;

  for (uint8_t i = 0; i < wordCount && remaining >= 2; ++i) {
    uint16_t v = static_cast<uint16_t>(p[0] | (static_cast<uint16_t>(p[1]) << 8));
    words[i] = v;
    p += 2;
    remaining -= 2;

    uint8_t lang = (remaining > 0 ? p[0] : 0) % 2;  // English / Japanese
    SendVRUWord(1, &words[i], lang);
  }

  // Call ReadVRUResults once to trigger the logic of parsing JSON / matching the registered word list
  uint16_t error_flags = 0;
  uint16_t num_results = 0;
  uint16_t mic_level = 0;
  uint16_t voice_level = 0;
  uint16_t voice_length = 0;
  uint16_t matches[10];

  ReadVRUResults(&error_flags, &num_results,
                 &mic_level, &voice_level,
                 &voice_length, matches);

  return 0;
}
