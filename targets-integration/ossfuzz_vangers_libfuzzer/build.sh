#!/bin/bash -eu
# Copyright 2025
#
# Build script for Vangers OSS-Fuzz integration (RLE only, standalone).
################################################################################

VANGERS_SRC="$SRC/Vangers"

# Check if the repository is cloned (useful for future expansion to other targets)
if [ ! -d "$VANGERS_SRC" ]; then
  echo "Vangers repo not found at $VANGERS_SRC" >&2
  exit 1
fi

# C++ options
CXXFLAGS="${CXXFLAGS:-} -std=c++17"

# Build only the self-contained RLE fuzzer
$CXX $CXXFLAGS \
  "$SRC/vangers_rle_fuzzer.cc" \
  -o "$OUT/vangers_rle_fuzzer" \
  $LIB_FUZZING_ENGINE
  