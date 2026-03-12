#!/bin/bash -eu
# Copyright 2025
#
# OSS-Fuzz build script for TRE.
#
################################################################################

# 1) Build and install TRE library (static linking to avoid .so issues)

cd "$SRC/tre"

# Generate configure script and other build files
./utils/autogen.sh

# Try to generate only static libraries for easier static linking with fuzzers
CFLAGS="$CFLAGS -fPIC"
CXXFLAGS="$CXXFLAGS -fPIC"

./configure \
  --disable-shared \
  --enable-static \
  CC="$CC" CFLAGS="$CFLAGS" \
  CXX="$CXX" CXXFLAGS="$CXXFLAGS"

make -j"$(nproc)"
make install

# Ensure pkg-config can find the newly installed tre.pc
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# 2) Compile fuzzers to $OUT
# Convention: Fuzzer source files are located in the $SRC directory, named tre_fuzz_*.cc

FUZZ_CXXFLAGS="$CXXFLAGS -std=c++17 $(pkg-config tre --cflags)"
FUZZ_LDFLAGS="$(pkg-config tre --libs)"

build_one_fuzzer() {
  local name="$1"
  local src="$SRC/${name}.cc"
  if [ -f "$src" ]; then
    echo "Building fuzzer: $name"
    $CXX $FUZZ_CXXFLAGS "$src" -o "$OUT/$name" \
      $LIB_FUZZING_ENGINE $FUZZ_LDFLAGS
  fi
}

# At least implement tre_fuzz_posix.cc; this one will definitely be built
build_one_fuzzer tre_fuzz_posix
build_one_fuzzer tre_fuzz_approx
# build_one_fuzzer tre_fuzz_wchar
