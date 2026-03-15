#!/bin/bash -eu
# Copyright 2025 Google LLC
# ... (License header) ...

################################################################################

# 1. Generate Arduino / FastLED stub headers to avoid dependencies on real hardware libraries

STUB_DIR="$SRC/arduino_stubs"
mkdir -p "${STUB_DIR}"

cat > "${STUB_DIR}/Arduino.h" << 'EOF'
#pragma once

#include <stdint.h>
#include <stddef.h>
#include <stdio.h>   // sprintf, etc.
#include <string.h>  // memcpy, etc.

typedef uint8_t byte;

// A minimalist serial class to swallow all Serial.print/println calls
class HardwareSerial {
public:
  template<typename... Args>
  void print(Args...) const {}

  template<typename... Args>
  void println(Args...) const {}

  template<typename... Args>
  void begin(Args...) const {}

  template<typename... Args>
  int available(Args...) const { return 0; }

  template<typename... Args>
  int read(Args...) const { return 0; }
};

// Common global serial objects on Arduino
// Using C++17 inline variables so they are not redefined when included in multiple files
inline HardwareSerial Serial;
inline HardwareSerial Serial1;

// Flash storage related macros degraded to standard constants
#define PROGMEM
struct __FlashStringHelper;
#define F(x) x

// Common byte operation macros
inline uint8_t highByte(uint16_t v) { return static_cast<uint8_t>(v >> 8); }
inline uint8_t lowByte(uint16_t v)  { return static_cast<uint8_t>(v & 0xFF); }

// Arduino-style min/max macros
#ifndef min
#define min(a,b) (( (a) < (b) ) ? (a) : (b))
#endif

#ifndef max
#define max(a,b) (( (a) > (b) ) ? (a) : (b))
#endif

// Simple stub, may be used by certain utility functions
inline unsigned long millis() { return 0; }

// Degraded implementations of common PROGMEM read macros
#define pgm_read_byte(addr)    (*(const uint8_t *)(addr))
#define pgm_read_word(addr)    (*(const uint16_t *)(addr))
#define pgm_read_dword(addr)   (*(const uint32_t *)(addr))

// memcpy_P on AVR; simply degrades to standard memcpy in the fuzzing environment
#ifndef memcpy_P
#define memcpy_P(dest, src, n) memcpy((dest), (src), (n))
#endif

#ifndef __FlashStringHelper_defined
#define __FlashStringHelper_defined
#endif

EOF

cat > "${STUB_DIR}/FastLED.h" << 'EOF'
#pragma once

#include <stdint.h>

// Provide only the CRGB type; FastLEDController will not be compiled/called during fuzzing
struct CRGB {
  uint8_t r;
  uint8_t g;
  uint8_t b;
};

EOF

# 2. Compile the core protocol and control code of the library itself

CLP_DIR="$SRC/CorsairLightingProtocol/src"

# Select only source files related to protocol parsing that do not depend on hardware peripherals
LIB_SOURCES=(
  CLPAdditionalFeatures.cpp
  CLPUtils.cpp
  CorsairLightingFirmware.cpp
  CorsairLightingFirmwareStorageStatic.cpp
  CorsairLightingProtocolController.cpp
  CorsairLightingProtocolResponse.cpp
  FanController.cpp
  LEDController.cpp
  TemperatureController.cpp
)

mkdir -p $OUT

pushd "${CLP_DIR}"

for src in "${LIB_SOURCES[@]}"; do
  echo "Compiling ${src}"
  $CXX $CXXFLAGS -std=c++17 -I"${CLP_DIR}" -I"${STUB_DIR}" \
      -DCLP_DEBUG=0 \
      -c "${src}" -o "${src%.cpp}.o"
done

# Package into a static library
ar rcs "$SRC/libclp.a" ./*.o

popd

# 3. Compile and link all fuzz_*.cc / fuzz_*.cpp files

for fuzz_src in "$SRC"/fuzz_*.cc "$SRC"/fuzz_*.cpp; do
  if [ ! -f "$fuzz_src" ]; then
    continue
  fi

  fuzz_name=$(basename "$fuzz_src")
  fuzz_name="${fuzz_name%.*}"

  echo "Building fuzzer ${fuzz_name} from ${fuzz_src}"

  $CXX $CXXFLAGS -std=c++17 \
      -I"${CLP_DIR}" -I"${STUB_DIR}" \
      "$fuzz_src" "$SRC/libclp.a" \
      $LIB_FUZZING_ENGINE \
      -o "$OUT/${fuzz_name}"
done
